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

#include "stm32f0xx_it.h"

#if (CFG_USBTMC_CFG_ENABLE_488)
usbtmc_response_capabilities_488_t const
#else
usbtmc_response_capabilities_t const
#endif
tud_usbtmc_app_capabilities  =
{
    .USBTMC_status = USBTMC_STATUS_SUCCESS,
    .bcdUSBTMC = USBTMC_VERSION,
    .bmIntfcCapabilities =
    {
        .listenOnly = 0,
        .talkOnly = 0,
        .supportsIndicatorPulse = 1
    },
    .bmDevCapabilities = {
        .canEndBulkInOnTermChar = 0
    },

#if (CFG_USBTMC_CFG_ENABLE_488)
    .bcdUSB488 = USBTMC_488_VERSION,
    .bmIntfcCapabilities488 =
    {
        .supportsTrigger = 1,
        .supportsREN_GTL_LLO = 0,
        .is488_2 = 1
    },
    .bmDevCapabilities488 =
    {
      .SCPI = 1,
      .SR1 = 0,
      .RL1 = 0,
      .DT1 =0,
    }
#endif
};

#define IEEE4882_STB_QUESTIONABLE (0x08u)
#define IEEE4882_STB_MAV          (0x10u)
#define IEEE4882_STB_SER          (0x20u)
#define IEEE4882_STB_SRQ          (0x40u)

static const char idn[] = "TinyUSB,ModelNumber,SerialNumber,FirmwareVer123456\r\n";
//static const char idn[] = "TinyUSB,ModelNumber,SerialNumber,FirmwareVer and a bunch of other text to make it longer than a packet, perhaps? lets make it three transfers...\n";
static volatile uint8_t status;

// 0=not query, 1=queried, 2=delay,set(MAV), 3=delay 4=ready?
// (to simulate delay)
static volatile uint16_t queryState = 0;
static volatile uint32_t queryDelayStart;
static volatile uint32_t bulkInStarted;
static volatile uint32_t idnQuery;

static uint32_t resp_delay = 125u; // Adjustable delay, to allow for better testing
static size_t buffer_len;
static size_t buffer_tx_ix; // for transmitting using multiple transfers
static uint8_t buffer[225]; // A few packets long should be enough.


static usbtmc_msg_dev_dep_msg_in_header_t rspMsg = {
    .bmTransferAttributes =
    {
      .EOM = 1,
      .UsingTermChar = 0
    }
};

bool tud_usbtmc_app_msg_trigger_cb(uint8_t rhport, usbtmc_msg_generic_t* msg) {
  (void)rhport;
  (void)msg;
  // Let trigger set the SRQ
  status |= IEEE4882_STB_SRQ;
  return true;
}

bool tud_usbtmc_app_msgBulkOut_start_cb(uint8_t rhport, usbtmc_msg_request_dev_dep_out const * msgHeader)
{
  (void)rhport;
  (void)msgHeader;
  buffer_len = 0;
  if(msgHeader->TransferSize > sizeof(buffer))
  {

    return false;
  }
  return true;
}

bool tud_usbtmc_app_msg_data_cb(uint8_t rhport, void *data, size_t len, bool transfer_complete)
{
  (void)rhport;

  // If transfer isn't finished, we just ignore it (for now)

  if(len + buffer_len < sizeof(buffer))
  {
    memcpy(&(buffer[buffer_len]), data, len);
    buffer_len += len;
  }
  else
  {
    return false; // buffer overflow!
  }
  queryState = transfer_complete;
  idnQuery = 0;

  if(transfer_complete && (len >=4) && !strncasecmp("*idn?",data,4))
  {
    idnQuery = 1;
  }
  if(transfer_complete && !strncasecmp("delay ",data,5))
  {
    queryState = 0;
    int d = atoi((char*)data + 5);
    if(d > 10000)
      d = 10000;
    if(d<0)
      d=0;
    resp_delay = (uint32_t)d;
  }
  return true;
}

bool tud_usbtmc_app_msgBulkIn_complete_cb(uint8_t rhport)
{
  (void)rhport;
  if((buffer_tx_ix == buffer_len) || idnQuery) // done
  {
    status &= (uint8_t)~(IEEE4882_STB_MAV); // clear MAV
    queryState = 0;
    bulkInStarted = 0;
    buffer_tx_ix = 0;
  }

  return true;
}

static unsigned int msgReqLen;

bool tud_usbtmc_app_msgBulkIn_request_cb(uint8_t rhport, usbtmc_msg_request_dev_dep_in const * request)
{
  (void)rhport;

  rspMsg.header.MsgID = request->header.MsgID,
  rspMsg.header.bTag = request->header.bTag,
  rspMsg.header.bTagInverse = request->header.bTagInverse;
  msgReqLen = request->TransferSize;

#ifdef xDEBUG
  uart_tx_str_sync("MSG_IN_DATA: Requested!\r\n");
#endif
  if(queryState == 0 || (buffer_tx_ix == 0))
  {
    TU_ASSERT(bulkInStarted == 0);
    bulkInStarted = 1;

    // > If a USBTMC interface receives a Bulk-IN request prior to receiving a USBTMC command message
    //   that expects a response, the device must NAK the request (*not stall*)
  }
  else
  {
    size_t txlen = tu_min32(buffer_len-buffer_tx_ix,msgReqLen);
    usbtmcd_transmit_dev_msg_data(rhport, &buffer[buffer_tx_ix], txlen,
        (buffer_tx_ix+txlen) == buffer_len, false);
    buffer_tx_ix += txlen;
  }
  // Always return true indicating not to stall the EP.
  return true;
}

void usbtmc_app_task_iter(void) {
  uint8_t const rhport = 0;
  switch(queryState) {
  case 0:
    break;
  case 1:
    queryDelayStart = HAL_GetTick();
    queryState = 2;
    break;
  case 2:
    if( (HAL_GetTick() - queryDelayStart) > resp_delay) {
      queryDelayStart = HAL_GetTick();
      queryState=3;
      status |= 0x10u; // MAV
      status |= 0x40u; // SRQ
    }
    break;
  case 3:
    if( (HAL_GetTick() - queryDelayStart) > resp_delay) {
      queryState = 4;
    }
    break;
  case 4: // time to transmit;
    if(bulkInStarted && (buffer_tx_ix == 0)) {
      if(idnQuery)
      {
        usbtmcd_transmit_dev_msg_data(rhport, idn,  tu_min32(sizeof(idn)-1,msgReqLen),true,false);
        queryState = 0;
        bulkInStarted = 0;
      }
      else
      {
        buffer_tx_ix = tu_min32(buffer_len,msgReqLen);
        usbtmcd_transmit_dev_msg_data(rhport, buffer, buffer_tx_ix, buffer_tx_ix == buffer_len, false);
      }
      // MAV is cleared in the transfer complete callback.
    }
    break;
  default:
    TU_ASSERT(false,);
    return;
  }
}

bool tud_usbtmc_app_initiate_clear_cb(uint8_t rhport, uint8_t *tmcResult)
{
  (void)rhport;
  *tmcResult = USBTMC_STATUS_SUCCESS;
  queryState = 0;
  bulkInStarted = false;
  status = 0;
  return true;
}

bool tud_usbtmc_app_check_clear_cb(uint8_t rhport, usbtmc_get_clear_status_rsp_t *rsp)
{
  (void)rhport;
  queryState = 0;
  bulkInStarted = false;
  status = 0;
  rsp->USBTMC_status = USBTMC_STATUS_SUCCESS;
  rsp->bmClear.BulkInFifoBytes = 0u;
  return true;
}
bool tud_usbtmc_app_initiate_abort_bulk_in_cb(uint8_t rhport, uint8_t *tmcResult)
{
  (void)rhport;
  bulkInStarted = 0;
  *tmcResult = USBTMC_STATUS_SUCCESS;
  return true;
}
bool tud_usbtmc_app_check_abort_bulk_in_cb(uint8_t rhport, usbtmc_check_abort_bulk_rsp_t *rsp)
{
  (void)rhport;
  (void)rsp;
  return true;
}

bool tud_usbtmc_app_initiate_abort_bulk_out_cb(uint8_t rhport, uint8_t *tmcResult)
{
  (void)rhport;
  *tmcResult = USBTMC_STATUS_SUCCESS;
  return true;

}
bool tud_usbtmc_app_check_abort_bulk_out_cb(uint8_t rhport, usbtmc_check_abort_bulk_rsp_t *rsp)
{
  (void)rhport;
  (void)rsp;
  return true;
}

void usmtmcd_app_bulkIn_clearFeature_cb(uint8_t rhport)
{
  (void)rhport;
}
void usmtmcd_app_bulkOut_clearFeature_cb(uint8_t rhport)
{
  (void)rhport;
}

// Return status byte, but put the transfer result status code in the rspResult argument.
uint8_t tud_usbtmc_app_get_stb_cb(uint8_t rhport, uint8_t *tmcResult)
{
  (void)rhport;
  uint8_t old_status = status;
  status = (uint8_t)(status & ~(IEEE4882_STB_SRQ)); // clear SRQ

  *tmcResult = USBTMC_STATUS_SUCCESS;
  // Increment status so that we see different results on each read...

  return old_status;
}

bool tud_usbtmc_app_indicator_pluse_cb(uint8_t rhport, tusb_control_request_t const * msg, uint8_t *tmcResult)
{
  (void)rhport;
  (void)msg;
  //led_indicator_pulse();
  *tmcResult = USBTMC_STATUS_SUCCESS;
  return true;
}
