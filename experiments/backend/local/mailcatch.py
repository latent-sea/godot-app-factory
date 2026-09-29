"""Catches every email the spike's auth sends and saves it to mail/<n>.eml."""
import asyncio, itertools, pathlib
from aiosmtpd.controller import Controller
from aiosmtpd.smtp import AuthResult

OUT = pathlib.Path(__file__).parent / "mail"
count = itertools.count(1)

class Save:
    async def handle_DATA(self, server, session, envelope):
        (OUT / f"{next(count)}.eml").write_bytes(envelope.content)
        return "250 OK"

def accept(server, session, envelope, mechanism, auth_data):
    return AuthResult(success=True)

controller = Controller(Save(), hostname="0.0.0.0", port=2500)
controller.start()
asyncio.get_event_loop().run_forever()
