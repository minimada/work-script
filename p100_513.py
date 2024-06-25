import asyncio
import argparse
import logging
import os

from plugp100.common.credentials import AuthCredential
from plugp100.discovery.tapo_discovery import TapoDiscovery
from plugp100.discovery.discovered_device import DiscoveredDevice
from plugp100.new.device_factory import connect, DeviceConnectConfiguration
from plugp100.new.tapoplug import TapoPlug
#from plugp100.responses.tapo_exception import TapoException, TapoError
from plugp100.new.errors.invalid_authentication import InvalidAuthentication

# use pre-defined device map, we can get mac information from
# discovered devices, but once we need get more about nickname or status,
# we have to authenticated. So simplly use pre-define map.
try:
    from  device_map import device_map
except ImportError:
    device_map = None

logger = logging.getLogger(__name__)
parser = argparse.ArgumentParser(formatter_class=argparse.RawTextHelpFormatter)

'''
Install:
conda create -n tapo python=3 cryptography requests certifi urllib3=1
conda activate tapo
pip install plugp100==5.1.3

Uasge:
# export TAPO_USERNAME and TAPO_PASSWORD in file tapo_env
source tapo_env
python3 p100.py -d
python3 p100.py -i 192.168.0.106 -o on
'''

async def discover(timeout: int = 5) -> list[DiscoveredDevice]:
    print(f"Scanning network...{timeout}s")
    discovered_devices = list(await TapoDiscovery.scan(timeout))
    for x in discovered_devices:
        logger.debug(x)

    return discovered_devices

example_text = '''example:
  python3 p100.py -i 192.168.0.106 -o on
  python3 p100.py -d -o off
'''

def parse_args():
    parser.add_argument("-i", "--ip", default="", help="Plug IP address")
    parser.add_argument(
        "-d", "--discovery", help="discovery plug in network", action="store_true"
    )
    parser.add_argument(
        "-o",
        "--on",
        default="show",
        help="Show plug state or set plug on/off",
        choices=["on", "off", "show"],
    )
    parser.add_argument(
        "-l",
        "--log",
        default="warning",
        help=("Provide logging level. " "Example --log debug', default='warning'"),
    )
    parser.add_argument("-s", "--device", default="",
                        help="Try to use device name connect to device")
    parser.epilog = example_text
    parser.description = "Turn on/off or show smart plug state"
    options = parser.parse_args()
    levels = {
        "critical": logging.CRITICAL,
        "error": logging.ERROR,
        "warn": logging.WARNING,
        "warning": logging.WARNING,
        "info": logging.INFO,
        "debug": logging.DEBUG,
    }
    level = levels.get(options.log.lower())
    logging.basicConfig(level=level)
    # logger.setLevel(logging.DEBUG) # disable this line
    logger.debug(f"level: {level}")
    logger.debug(f"IP address: {options.ip}")
    logger.debug(f"discovery: {options.discovery}")
    logger.debug(f"action: {options.on}")
    return options


# we are now store user password in env file
# TODO: save password in sha1 form like plugp100/requests/login_device.py used.
def getUserPass():
    username = os.getenv("TAPO_USERNAME", "<tapo_email>")
    password = os.getenv("TAPO_PASSWORD", "<tapo_password>")
    return username, password


def show_state(plug: TapoPlug):
    state = "on" if plug.is_on else "off"
    print(f"{plug.nickname}: {state}")

def print_discovered(dev: DiscoveredDevice):
    name = "unknow"
    if device_map and dev.mac in device_map:
        name =  device_map[dev.mac]
    else:
        name = dev.mac
    print(f"IP: {dev.ip}, device: {name}")

# Note: discovered device id does not equal authed device id, use mac
async def find_device_from_discoverd(name: str) -> list[DiscoveredDevice]:
    dev_mac = ""
    if device_map:
        for mac in device_map:
            if device_map[mac] == name:
                dev_mac = mac
        if len(dev_mac) == 0:
            print(f"Cannot find device: {name}")
            exit(1)
    else:
        print("Cannot get device map")
        exit(1)
    logger.debug(f"found mac {dev_mac} with name {name}")
    devices = await discover()
    for dev in devices:
        if dev.mac == dev_mac:
            return [dev]
    return []

async def connect_plug(credentials: AuthCredential, host: str) -> TapoPlug:
    device_configuration = DeviceConnectConfiguration(
        host=host,
        credentials=credentials,
        device_type="SMART.TAPOPLUG"
    )
    device = await connect(device_configuration)
    await device.update()
    return device

async def main():
    options = parse_args()
    username, password = getUserPass()
    devices = []

    if len(options.ip) == 0:
        # try to perform discovery
        if options.discovery :
            print("No IP address, try dicovery")
            devices = await discover()
        elif len(options.device) > 0:
            devices = await find_device_from_discoverd(options.device)

        # no ip set, no plug found, or too many plugs found
        if len(devices) < 1:
            print("Cannot get IP address")
            parser.print_help()
            exit(1)
        elif len(devices) > 1:
            for x in devices:
                print_discovered(x)
            print("\nPlease use -i to set which device to control\n")
            #parser.print_help()
            exit(1)
        else:
            ipaddr = devices.pop().ip
            print(f"dicovery finished, use IP: {ipaddr}")
    else:
        ipaddr = options.ip
    credentials = AuthCredential(username, password)
    plug = None

    try:
        plug = await connect_plug(credentials, ipaddr)
        if options.on == "on":
            await plug.turn_on()
        elif options.on == "off":
            await plug.turn_off()
        
        show_state(plug)
    except InvalidAuthentication as e:
        print(e)
    finally:
        if plug:
            await plug.client.close()


if __name__ == "__main__":
    loop = asyncio.new_event_loop()
    loop.run_until_complete(main())
    loop.run_until_complete(asyncio.sleep(0.1))
    loop.close()
