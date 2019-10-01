/*
 * The MIT License (MIT)
 *
 * Copyright (c) 2019 Nathan Conrad
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

#include <strings.h>
#include <stdlib.h>     /* atoi */
#include "tusb.h"
#include "main.h"
#include "usart.h"

#include "stm32f0xx_it.h"

#if (CFG_USBTMC_CFG_ENABLE_488)
static usbtmc_response_capabilities_488_t const
#else
static usbtmc_response_capabilities_t const
#endif
tud_usbtmc_app_capabilities  =
{
    .USBTMC_status = USBTMC_STATUS_SUCCESS,
    .bcdUSBTMC = USBTMC_VERSION,
    .bmIntfcCapabilities =
    {
        .listenOnly = 0,
        .talkOnly = 0,
        .supportsIndicatorPulse = 0
    },
    .bmDevCapabilities = {
        .canEndBulkInOnTermChar = 0
    },

#if (CFG_USBTMC_CFG_ENABLE_488)
    .bcdUSB488 = USBTMC_488_VERSION,
    .bmIntfcCapabilities488 =
    {
        .supportsTrigger = 0,
        .supportsREN_GTL_LLO = 0,
        .is488_2 = 0
    },
    .bmDevCapabilities488 =
    {
      .SCPI = 0, ///< Support SCPI command set
      .SR1 = 0,  ///< Supports SRQ (and has interrupt endpoint)
      .RL1 = 0,  ///< Implements 488.2 remote/local state machine
      .DT1 =0,   ///< Has 488.2 Trigger
    }
#endif
};

#define IEEE4882_STB_QUESTIONABLE (0x08u)
#define IEEE4882_STB_MAV          (0x10u)
#define IEEE4882_STB_SER          (0x20u)
#define IEEE4882_STB_SRQ          (0x40u)

static const char idn[] = "Conrad,SencoreIB,SN1,v0.1\r\n";
//static const char idn[] = "TinyUSB,ModelNumber,SerialNumber,FirmwareVer and a bunch of other text to make it longer than a packet, perhaps? lets make it three transfers...\n";
static volatile uint8_t status;

// 0=not query, 1=queried, 2=delay,set(MAV), 3=delay 4=ready?
// (to simulate delay)
static volatile uint16_t queryState = 0;
static volatile uint32_t bulkInStarted;

static size_t buffer_len;
static size_t buffer_tx_ix; // for transmitting using multiple transfers
static uint8_t buffer[225]; // A few packets long should be enough.

static uint8_t uartRxBuffer[225];
static size_t  uartRxBuffer_ix;


static usbtmc_msg_dev_dep_msg_in_header_t rspMsg = {
    .bmTransferAttributes =
    {
      .EOM = 1,
      .UsingTermChar = 0
    }
};

usbtmc_response_capabilities_488_t const * tud_usbtmc_get_capabilities_cb(void) {
	return &tud_usbtmc_app_capabilities;
}

bool tud_usbtmc_msgBulkOut_start_cb(usbtmc_msg_request_dev_dep_out const * msgHeader)
{

  (void)msgHeader;
  buffer_len = 0;
  if(msgHeader->TransferSize > sizeof(buffer))
  {
    return false;
  }
  return true;
}

bool tud_usbtmc_msg_data_cb(void *data, size_t len, bool transfer_complete)
{


	if(len + buffer_len < sizeof(buffer)) {
		memcpy(&(buffer[buffer_len]), data, len);
		buffer_len += len;
	} else {
		tud_usbtmc_start_bus_read();
		return false; // buffer overflow!
	}

	if(transfer_complete && (len >=4) && !strncasecmp("*idn?",data,5)) {
		queryState = 1;
		status |= IEEE4882_STB_MAV;
	} else if(transfer_complete && (len >=4) && !strncasecmp("fetch?",data,6)) {
		queryState = 2;
		status |= IEEE4882_STB_MAV;
	} else if(transfer_complete && (len >=4) && !strncasecmp("len?",data,4)) {
		queryState = 3;
		status |= IEEE4882_STB_MAV;
	} else {
		uart_tx_sync(buffer, buffer_len);
	}

	tud_usbtmc_start_bus_read();
	return true;
}

bool tud_usbtmc_msgBulkIn_complete_cb()
{

  if(queryState != 0) // done
  {
    status &= (uint8_t)~(IEEE4882_STB_MAV); // clear MAV
    queryState = 0;
    bulkInStarted = 0;
    buffer_tx_ix = 0;
  }
  tud_usbtmc_start_bus_read();
  return true;
}

static unsigned int msgReqLen;

bool tud_usbtmc_msgBulkIn_request_cb(usbtmc_msg_request_dev_dep_in const * request)
{


  rspMsg.header.MsgID = request->header.MsgID,
  rspMsg.header.bTag = request->header.bTag,
  rspMsg.header.bTagInverse = request->header.bTagInverse;
  msgReqLen = request->TransferSize;
  bulkInStarted = 1;
  // Always return true indicating not to stall the EP.
  return true;
}

void tud_usbtmc_open_cb(uint8_t interface_id) {
	tud_usbtmc_start_bus_read();
}

void usbtmc_app_task_iter(void) {
	if((queryState == 0) &&  uart_rx_char(&(uartRxBuffer[uartRxBuffer_ix])) ) {
		if(uartRxBuffer[uartRxBuffer_ix] == '\n') {
			  status = (uint8_t)(status | IEEE4882_STB_SRQ); // set SRQ
		}
		uartRxBuffer_ix++;
	}

	if(bulkInStarted && (queryState != 0u)) {
		switch(queryState) {
		case 1:
			tud_usbtmc_transmit_dev_msg_data( idn,  tu_min32(sizeof(idn)-1,msgReqLen),true,false);
			bulkInStarted = 0u;
			break;
		case 2:
			if(uartRxBuffer_ix > 0) {
				tud_usbtmc_transmit_dev_msg_data(uartRxBuffer,  tu_min32(uartRxBuffer_ix,msgReqLen),true,false);
				uartRxBuffer_ix = 0u;
				bulkInStarted = 0u;
			}
			break;
		case 3:
			tud_usbtmc_transmit_dev_msg_data(&uartRxBuffer_ix,  sizeof(uartRxBuffer_ix),true,false);
			bulkInStarted = 0u;
			break;
		}
		// MAV is cleared in the transfer complete callback.
	}
}

bool tud_usbtmc_initiate_clear_cb(uint8_t *tmcResult)
{

  *tmcResult = USBTMC_STATUS_SUCCESS;
  queryState = 0;
  bulkInStarted = false;
  status = 0;
  return true;
}

bool tud_usbtmc_check_clear_cb(usbtmc_get_clear_status_rsp_t *rsp)
{

  queryState = 0;
  bulkInStarted = false;
  status = 0;
  rsp->USBTMC_status = USBTMC_STATUS_SUCCESS;
  rsp->bmClear.BulkInFifoBytes = 0u;
  return true;
}
bool tud_usbtmc_initiate_abort_bulk_in_cb(uint8_t *tmcResult)
{

  bulkInStarted = 0;
  *tmcResult = USBTMC_STATUS_SUCCESS;
  return true;
}
bool tud_usbtmc_check_abort_bulk_in_cb(usbtmc_check_abort_bulk_rsp_t *rsp)
{

  (void)rsp;
  return true;
}

bool tud_usbtmc_initiate_abort_bulk_out_cb(uint8_t *tmcResult)
{
  *tmcResult = USBTMC_STATUS_SUCCESS;
  return true;

}
bool tud_usbtmc_check_abort_bulk_out_cb(usbtmc_check_abort_bulk_rsp_t *rsp)
{
  (void)rsp;
  tud_usbtmc_start_bus_read();
  return true;
}

void tud_usbtmc_bulkIn_clearFeature_cb()
{
}
void tud_usbtmc_bulkOut_clearFeature_cb()
{
  tud_usbtmc_start_bus_read();
}

// Return status byte, but put the transfer result status code in the rspResult argument.
uint8_t tud_usbtmc_get_stb_cb(uint8_t *tmcResult)
{

  uint8_t old_status = status;
  status = (uint8_t)(status & ~(IEEE4882_STB_SRQ)); // clear SRQ

  *tmcResult = USBTMC_STATUS_SUCCESS;
  // Increment status so that we see different results on each read...

  return old_status;
}

