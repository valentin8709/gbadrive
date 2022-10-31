import argparse
import signal
import time
import logging

from pathlib import Path
from rpi_rf import RFDevice

rfdevice = None

# pylint: disable=unused-argument
def exithandler(signal, frame):
    rfdevice.cleanup()
    exit(0)

logging.basicConfig(level=logging.INFO, datefmt='%Y-%m-%d %H:%M:%S',
                    format='%(asctime)-15s - [%(levelname)s] %(module)s: %(message)s')

parser = argparse.ArgumentParser(description='Receives a decimal code via a 433 MHz GPIO device')
parser.add_argument('-g', '--gpio', type=int, default=27,
                    help="GPIO pin (Default: 27)")
parser.add_argument('-o', '--output_file', type=str,
                    help="File where data will be written")
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
        logging.info(f"Received: {output_string}")

        if args.output_file:
            logfile = Path(args.output_file)
            logfile.write_text(output_string)
        rfdevice.cleanup()
        k = input("Press A to listen again or L+R to save and stop")
    time.sleep(0.2)
rfdevice.cleanup()
