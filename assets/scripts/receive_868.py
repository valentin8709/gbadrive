import time
import serial
import signal
import logging
import argparse

from pathlib import Path

def exithandler(signal, frame):
    logging.info("L + R pressed, exiting")
    exit(0)

# Logging manager
logging.basicConfig(level=logging.INFO, datefmt='%Y-%m-%d %H:%M:%S',
                    format='%(asctime)-15s - [%(levelname)s] %(module)s: %(message)s')

# Parsing arguments
parser = argparse.ArgumentParser(description='Receive bytes from a 868 MHz Lora UART device')

parser.add_argument('-o', '--output_file',
                    type=str,
                    help="File where data will be written",
                    default=None)
args = parser.parse_args()


# Check parameters
output_file = None
if args.output_file:
    output_file = Path(args.output_file)
    if output_file.is_dir():
        logging.critical(f"{output_file} seems to be a directory")
        exit(1)

# Set handler
signal.signal(signal.SIGINT, exithandler)

# Set up Lora device
lora = serial.Serial(port='/dev/ttyS0',
                     baudrate = 115200,
                     parity=serial.PARITY_NONE,
                     stopbits=serial.STOPBITS_ONE,
                     bytesize=serial.EIGHTBITS,
                     timeout=1)

# Read data from other Lora
logging.info("Reading data from Lora, L+R to exit")

data_read = None
while not data_read:
    data_read = lora.readline()

    if data_read:
        logging.info(f"Received: {data_read}")
        if output_file:
            output_file.write_bytes(data_read)
        k = input("Press A to listen again or L+R to save and stop")

    time.sleep(0.2)
