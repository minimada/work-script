import asyncio
import argparse
import logging
import os

from plugp100.api.tapo_client import TapoClient
from plugp100.common.credentials import AuthCredential
#from plugp100.discovery.arp_lookup import ArpLookup
from plugp100.discovery.tapo_discovery import TapoDiscovery
from plugp100.api.plug_device import PlugDevice
from plugp100.responses.device_state import PlugDeviceState
from plugp100.responses.tapo_exception import TapoException, TapoError

logger = logging.getLogger(__name__)
parser = argparse.ArgumentParser(formatter_class=argparse.RawTextHelpFormatter)

'''
Install:
conda create -n tapo python=3 cryptography requests certifi urllib3=1
conda activate tapo
pip install plugp100==4.0.3

Uasge:
# export TAPO_USERNAME and TAPO_PASSWORD in file tapo_env
source tapo_env
python3 p100.py -d
python3 p100.py -i 192.168.0.106 -o on
'''

async def discover():
    print("Scanning network...")
    discovered_devices = list(TapoDiscovery.scan(5))
    for x in discovered_devices:
        logger.debug(x)

    # if we can get IP from device, do we need this?
    # if len(discovered_devices) > 0:
    #     print("Trying to lookup with mac address")
    #     lookup = await ArpLookup.lookup(
    #         discovered_devices[0].mac.replace("-", ":"),
    #         "192.168.0.0/24",
    #         allow_promiscuous=False,
    #     )
    #     print(lookup)
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


def show_state(state: PlugDeviceState):
    info = state.info
    print(f"{info.nickname}: {state.device_on}")

async def main():
    options = parse_args()
    username, password = getUserPass()

    if len(options.ip) == 0:
        # try to perform discovery
        ips = []
        if options.discovery:
            print("No IP address, try dicovery")
            devices = await discover()
            if len(devices) > 0:
                for x in devices:
                    ips.append(x.ip)
                    print(f"find device ip: {x.ip}")
        # no ip set, no plug found, or too many plugs found
        if len(ips) != 1:
            if len(ips) < 1:
                print("Cannot get IP address")
            else:
                print("Please use -i to set which device to control\n")
            parser.print_help()
            exit(1)
        else:
            ipaddr = ips.pop()
            print(f"dicovery finished, use IP: {ipaddr}")
    else:
        ipaddr = options.ip
    credentials = AuthCredential(username, password)
    client = TapoClient.create(credentials, ipaddr)
    plug = PlugDevice(client)

    try:
        if options.on == "on":
            await plug.on()
        elif options.on == "off":
            await plug.off()
        # response come from TapoResponse.try_from_json, class Failure or Success
        res = await plug.get_state()
        show_state(res.value)
    except TapoException as e:
        if e.error_code == TapoError.INVALID_CREDENTIAL.value:
            print("Please check username and password")
        print(e)
    finally:
        await client.close()


if __name__ == "__main__":
    loop = asyncio.new_event_loop()
    loop.run_until_complete(main())
    loop.run_until_complete(asyncio.sleep(0.1))
    loop.close()
