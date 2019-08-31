#!/usr/bin/bash

# I run this script through msys2 on Windows

export DIAMOND=/c/lscc/diamond/3.11_x64
export FOUNDRY=${DIAMOND}/ispfpga
export PATH=$PATH:${DIAMOND}/tcltk/bin/
export MSIM=/c/Modeltech_pe_edu_10.4a/win32pe_edu
tclsh ${DIAMOND}/cae_library/simulation/script/cmpl_libs.tcl -device machxo2 -sim_path ${MSIM}