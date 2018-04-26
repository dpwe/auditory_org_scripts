"""Retrieve postings to AUDIORY from gmail personal account."""

from __future__ import print_function
from apiclient.discovery import build
from httplib2 import Http
from oauth2client import file, client, tools
import glob
import os
import sys
import base64

# Setup the Gmail API
SCOPES = 'https://www.googleapis.com/auth/gmail.readonly'
store = file.Storage('credentials.json')
creds = store.get()
if not creds or creds.invalid:
    flow = client.flow_from_clientsecrets('client_secret.json', SCOPES)
    creds = tools.run_flow(flow, store)
service = build('gmail', 'v1', http=creds.authorize(Http()))

argv = sys.argv

if not len(argv) == 3:
    raise ValueError("Usage: " + argv[0] + " <year> <month_num>")

year = int(argv[1])
month_num = int(argv[2])
if year < 1992 or year > 2050:
    raise ValueError("Year " + year + " is implausible.")
if month_num < 1 or month_num > 12:
    raise ValueError("Mobt " + month_num + " is out of range.")

date_format = '{:04d}-{:02d}-{:02d}'

first_date = date_format.format(year, month_num, 1)
if month_num < 12:
  last_date = date_format.format(year, month_num + 1, 1)
else:
  last_date = date_format.format(year + 1, 1, 1)

# Call the Gmail API
results = service.users().messages().list(userId='me', q='to:auditory@lists.mcgill.ca after:{:s} before:{:s}'.format(first_date, last_date)).execute()

ids = []
for message in results['messages']:
    ids.append(message['id'])

output_dir = str(year)

g = glob.glob('../src/postings/2017/*')
existing_message_numbers = sorted([int(os.path.basename(n)) for n in glob.glob(os.path.join(output_dir, "[1-9]*"))])
if existing_message_numbers:
    next_msg_num = existing_message_numbers[-1] + 1
else:
    next_msg_num = 1

#format = 'full'
format = 'raw'
for id_ in ids[::-1]:
    message = service.users().messages().get(userId='me', id=id_, format=format).execute()  # format='full' or 'raw'.
    if not 'raw' in message:
        print('Message keys:', message.keys())
        continue
    output_filename = os.path.join(output_dir, str(next_msg_num))
    with open(output_filename, 'w') as f:
        data = str(message['raw'])
        # Convert CR-LF to LF by removing all CRs.
        string_data = base64.b64decode(data, str('-_')).translate(None, '\r')
        f.write(string_data)
        print('Wrote', output_filename)
        next_msg_num += 1
