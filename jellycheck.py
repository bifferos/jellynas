#!/usr/bin/env python3

import sys
import requests
from pathlib import Path
from datetime import datetime, timezone, timedelta


HOME = Path.home()
DOT_FILE = HOME / ".jellycheck"
TOKEN = DOT_FILE.open("r").read().strip()


PREVIOUS_DATE_FILE = Path("/tmp/jellycheck.txt")



def init_previous_date():
    if not PREVIOUS_DATE_FILE.exists():
        date_now = datetime.now(tz=timezone.utc)
        very_old = date_now - timedelta(days=360)

        with PREVIOUS_DATE_FILE.open("w") as fp:
            fp.write(very_old.isoformat())


def read_previous_date():
    """Read date stored from the previous execution"""
    with PREVIOUS_DATE_FILE.open("r") as fp:
        return datetime.fromisoformat(fp.read().strip())


def write_date(lastactive):
    """Write the newly acquired date"""
    with PREVIOUS_DATE_FILE.open("w") as fp:
        fp.write(lastactive.isoformat())


def latest_activity(session_list):
    all_dates = []
    for session in session_list:
        iso_str = session["LastActivityDate"]
        iso_date = datetime.fromisoformat(iso_str)
        all_dates.append(iso_date)
        
    all_dates.sort()
    return all_dates[-1]    


def main():
    init_previous_date()

    old_date = read_previous_date()

    try:
        resp = requests.get("http://172.16.16.14:8096/Sessions", headers={"X-Emby-Token": TOKEN})
        session_list = resp.json()
    except Exception as e:
        print(f"Error making check on sessions {e}")
        sys.exit(0)    # We want to indicate active on any error, because the error is probably suspend in progress, and safer not to sleep for diagnostics
    
    if len(session_list) == 0:
        sys.exit("No sessions, inactive")   # no sessions, inactive

    new_date = latest_activity(session_list)
    if new_date == old_date:
        sys.exit("Session, but no new activity")   # session, but no activity since last poll: inactive

    write_date(new_date)


if __name__ == "__main__":
    main()
