#!/usr/bin/python
# -*- coding: utf8 -*-

import os.path
import sys
import platform
import re

OPT_SEPARATOR = '@'

def help():
    print "Usage: %s %s" % (sys.argv[0], "dest_file [#options] file1[#options1] file2[#options2] ...")
    sys.exit(1)

def fail(message):
    print message
    sys.exit(1)

def parse_options(sopts, track):
    opt_defs = [
        { 'name': 'lang', 're': r'^\w{3}$', },
        { 'name': 'delay', 're': r'^-?\d+ms$', },
        { 'name': 'title', 're': r'^.+$', }
    ]
    for s in sopts:
        for opt_def in opt_defs:
            if re.search(opt_def['re'], s):
                name = opt_def['name']
                if track.has_key(name):
                    fail("duplicate options %s=%s (prev: %s)" % (name, s, track[name]))
                if name == 'delay':
                     s = re.sub(r'ms$', '', s)
                track[name] = s
                break

def uprint(strings):
    for s in strings:
        print s.encode('utf-8')


if platform.system() == 'Windows':
    uargv = map(lambda s: unicode(s, 'mbcs'), sys.argv[1:]) 
else:
    uargv = map(lambda s: unicode(s, 'utf-8'), sys.argv[1:]) 

if not uargv:
    help()

tracks = {}
def_lang = 'rus'
dest_file = uargv[0]
for arg in uargv[1:]:
    file_n_opts = arg.split(OPT_SEPARATOR);
    track_file = file_n_opts[0]
    track = {
        'file': track_file,
    }
    parse_options(file_n_opts[1:], track)

    # global option (no file)
    if not track_file:
        def_lang = track['lang']
        continue

    ext = os.path.splitext(track_file)[1]

    if ext in ('.ac3', '.mp4'):
        track['type'] = 'audio'
        track['ext'] = ext
	# auto delay
        if not track.has_key('delay'):
            m = re.search(r'DELAY\s*(\d+)', track_file)
            if m:
                track['delay'] = m.group(1)
	# auto title
	if not track.has_key('title'):
	    m = re.search(r'(\d_\d)ch', track_file)
	    if m:
	      titles = {
		  '1_0': 'mono',
		  '2_0': 'stereo',
		  '3_2': '5.1',
	      }
	      for (k, v) in titles.items():
		if m.group(1) == k:
		  track['title'] = v
		  break
    elif ext in ('.mkv'):
        track['type'] = 'video'
    elif ext in ('.mkv'):
        track['type'] = 'video'
    elif ext in ('.srt'):
        track['type'] = 'subtitles'
    elif ext in ('.txt'):
        track['type'] = 'chapters'
    else:
        fail("Unknown file type %s" % track_file) 

    t = tracks.setdefault(track['type'], [])
    t.append(track)

#print repr(tracks) # FIXME

if not tracks.has_key('video'):
    fail('No video tracks')

if not tracks.has_key('audio'):
    fail('No audio tracks')

# global options
uprint(['--output', dest_file])
uprint(['--command-line-charset', 'utf-8'])
#uprint(['--output-charset', 'utf-8'])
#uprint(['--default-language', def_lang])
# chapters
if tracks.has_key('chapters'):
    tt = tracks['chapters']
    if len(tt) > 1:
        fail("Only single chapters file allowed")
    t = tt[0]
    uprint(['--chapter-charset', 'utf-8'])
    uprint(['--language', '-1:' + (t['lang'] if t.has_key('lang') else def_lang)])
    uprint(['--chapters', t['file']])

is_first_v_track = True
for t in tracks['video']:
    if is_first_v_track:
        if t.has_key('title'):
            uprint(['--track-name', '-1:' + t['title']])
	uprint(['--language', '-1:' + (t['lang'] if t.has_key('lang') else def_lang)])
        uprint(['--default-track', '-1:1'])
        uprint([t['file']])
        is_first_v_track = False
    else:
        uprint(['+' + t['file']])

is_first_a_track = True
for t in tracks['audio']:
    if is_first_a_track:
        uprint(['--default-track', '-1:1'])
	is_first_a_track = False
    if t.has_key('title'):
        uprint(['--track-name', '-1:' + t['title']])
    if t.has_key('delay'):
        uprint(['--sync', '-1:' + t['delay']])
    if t['ext'] == '.mp4':
        uprint(['--no-chapters'])
    uprint(['--language', '-1:' + (t['lang'] if t.has_key('lang') else def_lang)])
    uprint([t['file']])

if tracks.has_key('subtitles'):
    for t in tracks['subtitles']:
        uprint(['--default-track', '-1:0'])
        if t.has_key('title'):
            uprint(['--track-name', '-1:' + t['title']])
        if t.has_key('delay'):
            uprint(['--sync', '-1:' + t['delay']])
	uprint(['--language', '-1:' + (t['lang'] if t.has_key('lang') else def_lang)])
        uprint(['--sub-charset', '-1:ucs-2'])
        uprint([t['file']])

"""
--output file

--default-language language-code

--chapters file-name
--chapter-language language-code
--chapter-charset character-set (UTF-8)

--no-chapters
--default-track TID[:bool]
--track-name TID:name
--language TID:language
--sync TID:d (delay)

--sub-charset TID:character-set ()

--display-dimensions TID:widthxheight
--aspect-ratio-factor TID:factor|n/d

"""
