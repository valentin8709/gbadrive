#!/usr/bin/env python3

import argparse
import signal
import sys
import time
import logging

from pathlib import Path
from rpi_rf import RFDevice

rfdevice = None

# pylint: disable=unused-argument
def exithandler(signal, frame):
    rfdevice.cleanup()
    sys.exit(0)

logging.basicConfig(level=logging.INFO, datefmt='%Y-%m-%d %H:%M:%S',
                    format='%(asctime)-15s - [%(levelname)s] %(module)s: %(message)s', )

parser = argparse.ArgumentParser(description='Receives a decimal code via a 433MHz GPIO device')
parser.add_argument('-g', dest='gpio', type=int, default=27,
                    help="GPIO pin (Default: 27)")
parser.add_argument('-o', dest='output_file', help="File output")
args = parser.parse_args()

signal.signal(signal.SIGINT, exithandler)
rfdevice = RFDevice(args.gpio)
rfdevice.enable_rx()
timestamp = None
logging.info("Listening for codes on GPIO " + str(args.gpio))
while True:
    if rfdevice.rx_code_timestamp != timestamp:
        timestamp = rfdevice.rx_code_timestamp
        output_string = (str(rfdevice.rx_code) +
                         ";" + str(rfdevice.rx_pulselength) +
                         ";" + str(rfdevice.rx_proto))
        logging.info(output_string)
        if args.output_file:
            logfile = Path(args.output_file)
            logfile.write_text(output_string)
        rfdevice.cleanup()
        exit(0)
    time.sleep(0.01)
rfdevice.cleanup()
