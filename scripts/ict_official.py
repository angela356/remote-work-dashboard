"""Rebuild the four firm-size files of the dashboard from the official Eurostat ICT exports.

Reads raw_data/isoc_ci_mvis_defaultview_spreadsheet.xlsx and raw_data/isoc_ci_ras_defaultview_spreadsheet.xlsx
(the 'default view' spreadsheets downloaded from the Eurostat data browser) and writes, in data/:
  firm_meetings_size.json   remote meetings, EU-27, by size class, 2022 and 2024
  firm_access_size.json     remote access to e-mail AND documents AND business applications, EU-27, by size class
  firm_access_type.json     remote access by resource type and size class, EU-27, 2024
  firm_meetings_country.json remote meetings by country, enterprises with 10+ employees, 2024
Usage (from the repository root): python3 scripts/ict_official.py
"""
import json, os, warnings
import pandas as pd
warnings.filterwarnings('ignore')
RAW = os.environ.get('RAW_DIR', 'raw_data')
MVIS = os.path.join(RAW, 'isoc_ci_mvis_defaultview_spreadsheet.xlsx')
RAS = os.path.join(RAW, 'isoc_ci_ras_defaultview_spreadsheet.xlsx')
SIZES = {'From 10 to 49 persons employed': ('Small (10–49)', 'small'),
         'From 50 to 249 persons employed': ('Medium (50–249)', 'medium'),
         '250 persons employed or more': ('Large (250+)', 'large'),
         '10 persons employed or more': ('All (10+)', 'all')}
ISO = {'Belgium':'BE','Bulgaria':'BG','Czechia':'CZ','Denmark':'DK','Germany':'DE','Estonia':'EE','Ireland':'IE',
       'Greece':'EL','Spain':'ES','France':'FR','Croatia':'HR','Italy':'IT','Cyprus':'CY','Latvia':'LV','Lithuania':'LT',
       'Luxembourg':'LU','Hungary':'HU','Malta':'MT','Netherlands':'NL','Austria':'AT','Poland':'PL','Portugal':'PT',
       'Romania':'RO','Slovenia':'SI','Slovakia':'SK','Finland':'FI','Sweden':'SE','Iceland':'IS','Norway':'NO',
       'Montenegro':'ME','Serbia':'RS','Türkiye':'TR','Bosnia and Herzegovina':'BA','North Macedonia':'MK','Albania':'AL'}

def sheets(path):
    """Yield (metadata, {row label: {year: value}}) for every data sheet of a default-view export."""
    xl = pd.ExcelFile(path)
    for s in [x for x in xl.sheet_names if x.startswith('Sheet')]:
        df = pd.read_excel(path, sheet_name=s, header=None)
        meta = {str(df.iloc[i, 0]).strip(): str(df.iloc[i, 2]).strip() for i in range(9)}
        t = [i for i in range(len(df)) if str(df.iloc[i, 0]).strip() == 'TIME'][0]
        years = {j: str(df.iloc[t, j]).strip().split('.')[0] for j in range(1, df.shape[1])
                 if str(df.iloc[t, j]).strip() not in ('nan', '')}
        rows = {}
        for i in range(t + 2, len(df)):
            label = str(df.iloc[i, 0]).strip()
            if not label or label == 'nan':
                continue
            vals = {}
            for j, y in years.items():
                try:
                    vals[y] = round(float(df.iloc[i, j]), 2)
                except (TypeError, ValueError):
                    pass
            if vals:
                rows[label] = vals
        yield meta, rows

def eu(rows):
    return next((v for k, v in rows.items() if k.startswith('European Union')), {})

IND, SIZE, UNIT = 'Information society indicator', 'Size classes in number of persons employed', 'Unit of measure'

# remote meetings
meet_size, meet_country = {}, []
for meta, rows in sheets(MVIS):
    if 'conducted remote meetings' not in meta.get(IND, ''):
        continue
    sc = meta.get(SIZE)
    if sc in SIZES:
        v = eu(rows)
        meet_size[sc] = {'size': SIZES[sc][0], 'size_code': SIZES[sc][1], 'y2022': v.get('2022'), 'y2024': v.get('2024')}
    if sc == '10 persons employed or more':
        for name, v in rows.items():
            if name in ISO and '2024' in v:
                meet_country.append({'geo': ISO[name], 'country': name, 'pct': v['2024']})
        meet_country.sort(key=lambda r: -r['pct'])
        meet_country.append({'geo': 'EU', 'country': 'EU average', 'pct': eu(rows).get('2024')})

# remote access (unit: percentage of all enterprises)
TYPES = [('remote access to the email system of the enterprise', 'E-mail system'),
         ('remote access to the documents of the enterprise', 'Documents'),
         ('remote access to the business applications or software', 'Business applications')]
ALL3 = 'remote access to the email system and documents and business applications'
access_size, access_type = {}, {lbl: {'type': lbl} for _, lbl in TYPES}
for meta, rows in sheets(RAS):
    if meta.get(UNIT) != 'Percentage of enterprises' or meta.get(SIZE) not in SIZES:
        continue
    ind, sc, v = meta.get(IND, ''), meta.get(SIZE), eu(rows)
    if ALL3 in ind:
        access_size[sc] = {'size': SIZES[sc][0], 'size_code': SIZES[sc][1], 'y2022': v.get('2022'), 'y2024': v.get('2024')}
    for key, lbl in TYPES:
        if key in ind:
            access_type[lbl][SIZES[sc][1]] = v.get('2024')

order = list(SIZES)
out = {'firm_meetings_size': [meet_size[s] for s in order],
       'firm_access_size': [access_size[s] for s in order],
       'firm_access_type': [access_type[lbl] for _, lbl in TYPES],
       'firm_meetings_country': meet_country}
for name, data in out.items():
    with open(os.path.join('data', name + '.json'), 'w') as f:
        json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
    print(name, json.dumps(data, ensure_ascii=False)[:160])
