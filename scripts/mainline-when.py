#!/usr/bin/env python3
# Quickie script to estimate mainline release dates.
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# -*- coding: utf-8 -*-
#
__author__ = 'Konstantin Ryabitsev <konstantin@linuxfoundation.org>'


import argparse
import requests
import datetime
import logging
import json
import sys

RELEASES_JSON = 'https://www.kernel.org/releases.json'
WINDOW_DAYS = 14
RC_COUNT = 7
CYCLE_DAYS = WINDOW_DAYS + (RC_COUNT * 7)
VERSION = '1.0'
# This is where the minor version number starts looking "too big" and
# we go to the "next major version dot-zero" -- Linus says that it will
# likely always be after 19. The only time this went to 20 was for
# 4.20, and the only explanation we can give is that everyone was too
# high at the time to notice.
TOOBIG = 19

logger = logging.getLogger('mainline-when')


def parse_version(ver):
    rcn = None
    if ver.find('-') > 0:
        ver, rc = ver.split('-')
        rcn = int(rc[2:])
    jv, nv = ver.split('.')
    majver = int(jv)
    minver = int(nv)

    return majver, minver, rcn


def main(estnext=3, forcever=None, rjson=None):
    if rjson is None:
        rses = requests.session()
        headers = {'User-Agent': f'mainline-when/{VERSION}'}
        rses.headers.update(headers)
        resp = rses.get(RELEASES_JSON)
        resp.raise_for_status()
        rels = json.loads(resp.content)
    else:
        with open(rjson, 'r') as fh:
            content = fh.read()
        rels = json.loads(content)

    release = None
    for release in rels['releases']:
        if release['moniker'] != 'mainline':
            continue
        break
    if release is None:
        logger.critical('Could not find mainline release info in %s', RELEASES_JSON)
        sys.exit(1)

    ics = list()
    if forcever:
        majver, minver, rcn = parse_version(forcever)
    else:
        majver, minver, rcn = parse_version(release.get('version'))
    crel = datetime.datetime.strptime(release['released']['isodate'], '%Y-%m-%d')
    if rcn:
        logger.info(f'current status: {majver}.{minver}-rc{rcn}')
        mrel = crel - datetime.timedelta(days=(7*rcn)+7)
        if rcn < 8:
            frel = mrel + datetime.timedelta(days=CYCLE_DAYS)
        else:
            # Add 7 days to the latest release and hope for the best
            frel = crel + datetime.timedelta(days=7)
    else:
        # We're currently in a merge window
        minver += 1
        if minver > TOOBIG:
            majver += 1
            minver = 0
        logger.info(f'current status: {majver}.{minver} merge window')
        mrel = crel
        frel = crel + datetime.timedelta(days=CYCLE_DAYS)
    logger.info('---')
    wo = mrel + datetime.timedelta(days=1)
    wc = mrel + datetime.timedelta(days=WINDOW_DAYS)
    ics.append((majver, minver, wo, wc, frel))
    if rcn:
        logger.info(f'{majver}.{minver} window open : {wo.strftime("%Y-%m-%d")}')
        logger.info(f'{majver}.{minver} window close: {wc.strftime("%Y-%m-%d")}')
        logger.info(f'{majver}.{minver} rc{rcn}         : {crel.strftime("%Y-%m-%d")}  <-- you are here')
    else:
        logger.info(f'{majver}.{minver} window open : {wo.strftime("%Y-%m-%d")}  <-- you are here')
        logger.info(f'{majver}.{minver} window close: {wc.strftime("%Y-%m-%d")}')

    logger.info(f'{majver}.{minver} final       : {frel.strftime("%Y-%m-%d")}')

    # Estimate next versions
    for nextver in range(minver+1, minver+estnext+1):
        if nextver > TOOBIG:
            estmaj = majver + 1
            estmin = nextver - (TOOBIG + 1)
        else:
            estmaj = majver
            estmin = nextver
        logger.info('---')
        wo = frel + datetime.timedelta(days=1)
        wc = frel + datetime.timedelta(days=WINDOW_DAYS)
        logger.info(f'{estmaj}.{estmin} window open : {wo.strftime("%Y-%m-%d")}')
        logger.info(f'{estmaj}.{estmin} window close: {wc.strftime("%Y-%m-%d")}')
        frel = frel + datetime.timedelta(days=CYCLE_DAYS)
        logger.info(f'{estmaj}.{estmin} final       : {frel.strftime("%Y-%m-%d")}')
        ics.append((estmaj, estmin, wo, wc, frel))
    logger.info('---')
    logger.info('NB: All dates set in the future are estimates.')
    return ics


def write_ics(ics, outfile, domain):
    if not domain:
        domain = 'mainline-when.local'
    now = datetime.datetime.now()
    admonition = 'NOTE: all dates set in the future are estimates.'
    with open(outfile, 'w') as fh:
        fh.write('BEGIN:VCALENDAR\r\n')
        fh.write('VERSION:2.0\r\n')
        fh.write(f'PRODID:{domain}\r\n')
        fh.write('METHOD:PUBLISH\r\n')
        for majver, minver, wo, wc, frel in ics:
            # Merge window
            fh.write('BEGIN:VEVENT\r\n')
            fh.write(f'UID:kernel-v{majver}.{minver}-merge-window@{domain}\r\n')
            fh.write(f'SUMMARY:Kernel v{majver}.{minver} merge window\r\n')
            if wo > now:
                fh.write(f'DESCRIPTION:{admonition}\r\n')
            fh.write('CLASS:PUBLIC\r\n')
            fh.write(f'DTSTART;VALUE=DATE:{wo.strftime("%Y%m%d")}\r\n')
            fh.write(f'DTEND;VALUE=DATE:{wc.strftime("%Y%m%d")}\r\n')
            fh.write(f'CREATED:{now.strftime("%Y%m%d")}\r\n')
            fh.write(f'LAST-MODIFIED:{now.strftime("%Y%m%d")}\r\n')
            fh.write('END:VEVENT\r\n')
            # rc1
            fh.write('BEGIN:VEVENT\r\n')
            fh.write(f'UID:kernel-v{majver}.{minver}-rc1@{domain}\r\n')
            fh.write(f'SUMMARY:Kernel v{majver}.{minver}-rc1 release\r\n')
            if wc > now:
                fh.write(f'DESCRIPTION:{admonition}\r\n')
            fh.write('CLASS:PUBLIC\r\n')
            fh.write(f'DTSTART;VALUE=DATE:{wc.strftime("%Y%m%d")}\r\n')
            fh.write(f'CREATED:{now.strftime("%Y%m%d")}\r\n')
            fh.write(f'LAST-MODIFIED:{now.strftime("%Y%m%d")}\r\n')
            fh.write('END:VEVENT\r\n')
            # final
            fh.write('BEGIN:VEVENT\r\n')
            fh.write(f'UID:kernel-v{majver}.{minver}-final@{domain}\r\n')
            fh.write(f'SUMMARY:Kernel v{majver}.{minver} final release\r\n')
            if frel > now:
                fh.write(f'DESCRIPTION:{admonition} If deemed necessary, this may end up being another -rc release.')
                fh.write('\r\n')

            fh.write('CLASS:PUBLIC\r\n')
            fh.write(f'DTSTART;VALUE=DATE:{frel.strftime("%Y%m%d")}\r\n')
            fh.write(f'CREATED:{now.strftime("%Y%m%d")}\r\n')
            fh.write(f'LAST-MODIFIED:{now.strftime("%Y%m%d")}\r\n')
            fh.write('END:VEVENT\r\n')
        fh.write('END:VCALENDAR\r\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-n', '--next', type=int, default=3, help='How many versions to estimate')
    parser.add_argument('-i', '--ics-out', help='Write an .ics file instead')
    parser.add_argument('-d', '--ics-domain', help='Domain to use for ics generation')
    parser.add_argument('-r', '--releases-json', help='Use this local copy of releases.json')
    parser.add_argument('--force-version', help='Force version to be this (testing only)')
    cmdargs = parser.parse_args()

    logger.setLevel(logging.DEBUG)
    ch = logging.StreamHandler()
    formatter = logging.Formatter('%(message)s')
    ch.setFormatter(formatter)
    if cmdargs.ics_out:
        ch.setLevel(logging.CRITICAL)
    else:
        ch.setLevel(logging.INFO)
    logger.addHandler(ch)

    icsdata = main(estnext=cmdargs.next, forcever=cmdargs.force_version, rjson=cmdargs.releases_json)
    if cmdargs.ics_out:
        write_ics(icsdata, cmdargs.ics_out, cmdargs.ics_domain)
