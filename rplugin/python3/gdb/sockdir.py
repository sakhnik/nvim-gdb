"""."""

import tempfile


class SockDir:
    """Unique directory for the rendez-vous point."""

    def __init__(self):
        """ctor."""
        self.sock_dir = tempfile.TemporaryDirectory(prefix='nvimgdb-sock')

    def cleanup(self):
        """dtor."""
        if self.sock_dir:
            self.sock_dir.cleanup()
            self.sock_dir = None

    def get(self):
        """Access the directory."""
        return self.sock_dir.name
