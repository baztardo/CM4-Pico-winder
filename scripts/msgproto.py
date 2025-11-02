# Minimal msgproto stub for build system
# This provides just enough functionality to satisfy buildcommands.py imports

class MessageParser:
    def __init__(self):
        pass

class PT_int32:
    def parse(self, data, offset):
        return (0, 0)  # Return dummy values

def lookup_output_params(msgformat):
    return []

def lookup_params(msgformat):
    return []

# Default message definitions
DefaultMessages = {}

# Constants
MESSAGE_MAX = 64
MESSAGE_MIN = 5
