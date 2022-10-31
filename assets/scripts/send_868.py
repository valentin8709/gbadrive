import time
import serial
import logging
import argparse

from pathlib import Path

# Logging manager
logging.basicConfig(level=logging.INFO, datefmt='%Y-%m-%d %H:%M:%S',
                    format='%(asctime)-15s - [%(levelname)s] %(module)s: %(message)s')

# Parsing arguments
parser = argparse.ArgumentParser(description='Receive bytes from a 868 MHz Lora UART device')

parser.add_argument('-f','--file',
                    type=str,
                    metavar='INPUT_FILE',
                    help="File from which data will be send")
args = parser.parse_args()

# Check parameters
input_file = Path(args.file)
if not input_file.is_file():
    logging.critical(f"{input_file} not found")
    exit(1)

# Setup Lora device
lora = serial.Serial(port='/dev/ttyS0',
                     baudrate = 9600,
                     parity=serial.PARITY_NONE,
                     stopbits=serial.STOPBITS_ONE,
                     bytesize=serial.EIGHTBITS,
                     timeout=1)

# Send the data to other Lora
s = lora.write(intput_file.read_bytes())
# Delay of 200ms
time.sleep(0.2)

# Exiting
exit(0)
