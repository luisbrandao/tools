#!/usr/bin/env python3.11
"""Simple HTTP Server with Upload Support.

Modernized Python 3 version of the original SimpleHTTPServerWithUpload.
Serves files from a directory tree and accepts file uploads via POST.

Usage:
    python3 ftpython.py              # Serve current dir on port 8000
    python3 ftpython.py 8080         # Serve current dir on port 8080
    python3 ftpython.py /path/to/dir # Serve specified dir on port 8000
    python3 ftpython.py /path/to/dir 9000  # Serve specified dir on port 9000
"""

__version__ = "2.0"

import argparse
import cgi
import html
import io
import mimetypes
import os
import posixpath
import shutil
import sys
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.parse import quote, unquote


class UploadRequestHandler(SimpleHTTPRequestHandler):
    """HTTP request handler with GET/HEAD/POST (upload) support."""

    server_version = f"SimpleHTTPWithUpload/{__version__}"

    # Override directory_listing to include an upload form
    def list_directory(self, path):
        """Produce a directory listing with an upload form."""
        try:
            listings = os.listdir(path)
        except PermissionError:
            self.send_error(403, "No permission to list directory")
            return

        listings.sort(key=lambda a: a.lower())
        displaypath = html.escape(unquote(self.path))

        content = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Directory listing for {displaypath}</title>
<style>
  body {{ font-family: system-ui, -apple-system, sans-serif; margin: 2em; background: #f8f9fa; color: #212529; }}
  h1 {{ font-size: 1.5em; border-bottom: 1px solid #dee2e6; padding-bottom: 0.5em; }}
  a {{ color: #0d6efd; text-decoration: none; }}
  a:hover {{ text-decoration: underline; }}
  ul {{ list-style: none; padding: 0; }}
  li {{ padding: 0.25em 0; border-bottom: 1px solid #e9ecef; }}
  li.dir > a::after {{ content: " /"; color: #6c757d; }}
  li.link > a::after {{ content: " @"; color: #fd7e14; }}
  form {{ margin: 1.5em 0; padding: 1em; background: #fff; border: 1px solid #dee2e6; border-radius: 6px; }}
  input[type="file"] {{ margin-right: 0.5em; }}
  button {{ background: #0d6efd; color: #fff; border: none; padding: 0.4em 1em; border-radius: 4px; cursor: pointer; }}
  button:hover {{ background: #0b5ed7; }}
  small {{ color: #6c757d; }}
</style>
</head>
<body>
<h1>Directory listing for {displaypath}</h1>
<form enctype="multipart/form-data" method="post">
  <input name="file" type="file"/>
  <button type="submit">Upload</button>
</form>
<ul>
"""
        for name in listings:
            fullname = os.path.join(path, name)
            linkname = name
            classes = []

            if os.path.isdir(fullname):
                linkname = name + "/"
                classes.append("dir")
            if os.path.islink(fullname):
                classes.append("link")

            class_attr = f' class="{" ".join(classes)}"' if classes else ""
            content += f'<li{class_attr}><a href="{quote(linkname)}">{html.escape(name)}</a></li>\n'

        content += """</ul>
<small>SimpleHTTPWithUpload/{version}</small>
</body>
</html>""".format(version=__version__)

        encoded = content.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def do_POST(self):
        """Handle file upload via POST multipart/form-data."""
        try:
            content_type = self.headers.get("Content-Type", "")
            if "multipart/form-data" not in content_type:
                self.send_error(400, "Expected multipart/form-data")
                return

            # Parse the multipart form data
            pd = cgi.FieldStorage(
                fp=self.rfile,
                headers=self.headers,
                environ={
                    "REQUEST_METHOD": "POST",
                    "CONTENT_TYPE": content_type,
                }
            )

            file_item = pd["file"]
            if not file_item.filename:
                self.send_error(400, "No filename provided")
                return

            # Security: strip path components from uploaded filename
            filename = os.path.basename(file_item.filename)
            upload_path = os.path.join(self.directory, filename)

            # Read and write the file
            with open(upload_path, "wb") as out:
                while True:
                    chunk = file_item.file.read(65536)
                    if not chunk:
                        break
                    out.write(chunk)

            filesize = os.path.getsize(upload_path)
            referer = self.headers.get("Referer", "/")

            result_html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Upload Result</title>
<style>
  body {{ font-family: system-ui, -apple-system, sans-serif; margin: 2em; }}
  .success {{ color: #198754; }}
  h2 {{ border-bottom: 1px solid #dee2e6; padding-bottom: 0.5em; }}
</style>
</head>
<body>
<h2>Upload Result</h2>
<p class="success"><strong>Success:</strong> File '{html.escape(filename)}' uploaded ({filesize:,} bytes)</p>
<a href="{html.escape(referer)}">Back</a>
</body>
</html>"""

            encoded = result_html.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(encoded)))
            self.end_headers()
            self.wfile.write(encoded)

            print(f"Uploaded {filename} ({filesize:,} bytes) by {self.client_address}")

        except KeyError as e:
            self.send_error(400, f"Missing form field: {e}")
        except PermissionError:
            self.send_error(403, "Permission denied")
        except Exception as e:
            self.send_error(500, f"Upload failed: {e}")


def run(server_class=HTTPServer, handler_class=UploadRequestHandler):
    """Run the HTTP server."""
    parser = argparse.ArgumentParser(
        description="Simple HTTP Server with Upload Support"
    )
    parser.add_argument(
        "directory", nargs="?", default=".",
        help="Directory to serve (default: current directory)"
    )
    parser.add_argument(
        "port", nargs="?", type=int, default=8000,
        help="Port to listen on (default: 8000)"
    )
    args = parser.parse_args()

    # Set the directory on the handler class (required by SimpleHTTPRequestHandler)
    handler_class.directory = os.path.abspath(args.directory)

    server_address = ("", args.port)
    httpd = server_class(server_address, handler_class)

    print(f"Serving {handler_class.directory} on port {args.port}")
    print(f"Press Ctrl+C to stop.")

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        httpd.server_close()


if __name__ == "__main__":
    run()
