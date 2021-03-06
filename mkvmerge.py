#!/usr/bin/python
# -*- coding: utf8 -*-

import os.path
import sys
import platform
import re
import copy
import tempfile
import codecs

OPT_SEPARATOR = '@'

TRACK_EXTS = {
    '.ac3': 'audio',
    '.mp4': 'audio',
    '.mp3': 'audio',
    '.mkv': 'video',
    '.txt': 'chapters',
    '.srt': 'subtitles',
    '.idx': 'subtitles',
}

TRACK_TYPES = {
    'audio': {
        'valid_opts': 'lang title delay'.split(),
        'guess_opts': 'delay title'.split(),
    },
    'video': {
        'valid_opts': 'lang title delay'.split(),
    },
    'chapters': {
        'valid_opts': 'lang'.split(),
    },
    'subtitles': {
        'valid_opts': 'lang title delay'.split(),
        'guess_opts': 'delay'.split(),
    },
    'DEFAULT': {
       'valid_opts': 'lang filetitle'.split(),
    },
}

OPTION_DEFS = [
    dict(name='delay', re=r'^(-?\d+)ms$'),
    dict(name='lang', re=r'^([a-z]{3})$'),
    dict(name='filetitle', re=r'^ft:(.+)$'),
    dict(name='title', re=r'^(.+)$'),
]

def help():
    print "Usage: %(cmd)s dest_file [%(sep)sdef_lang] file1[%(sep)soptions1] file2[%(sep)soptions2] ..." % { 'cmd': sys.argv[0], 'sep': OPT_SEPARATOR }
    sys.exit(1)


def fail(message):
    print message
    sys.exit(1)


def parse_options(opt_strs):
    opts = {}
    for s in opt_strs:
        for opt_def in OPTION_DEFS:
            name, regexp = opt_def['name'], opt_def['re']
            m = re.search(regexp, s)
            if m:
                if opts.has_key(name):
                    fail("duplicate options %s=%s (prev: %s)" % (name, s, opts[name]))
                opts[name] = m.group(1)
                break

    return opts


def guess_options(file, guess_opts):
    opts = {}
    if 'delay' in guess_opts:
        m = re.search(r'DELAY\s*(\d+)', file)
        if m:
            opts['delay'] = m.group(1)

    if 'title' in guess_opts:
        m = re.search(r'(\d_\d)ch', file)
        if m:
            titles = {
              '1_0': 'mono',
              '2_0': 'stereo',
              '3_2': '5.1',
            }
            if titles.has_key(m.group(1)):
                opts['title'] = titles[m.group(1)]

    return opts

def print_options(opts):
    if opts.has_key('title'):
        uprint('--track-name', '-1:' + opts['title'])
    if opts.has_key('lang'):
        uprint('--language', '-1:' + opts['lang'])
    if opts.has_key('delay'):
        uprint('--sync', '-1:' + opts['delay'])


arg_enc = 'mbcs' if platform.system() == 'Windows' else 'utf-8'
uargv = [unicode(s, arg_enc) for s in sys.argv[1:]] 

if not uargv:
    help()


tracks = {}
def_opts = dict(lang = 'rus')
dest_file = uargv[0]
for arg in uargv[1:]:
    file_n_opts = arg.split(OPT_SEPARATOR);
    track_file = file_n_opts[0]

    # Get track parameters
    if track_file:
        try:
            ext = os.path.splitext(track_file)[1]
            track_type = TRACK_EXTS[ext]
        except:
            fail("Unknown file type %s" % track_file) 
    else:
        track_type = 'DEFAULT'

    valid_opts_list = TRACK_TYPES[track_type]['valid_opts']
    guess_opts_list = TRACK_TYPES[track_type].get('guess_opts', None)

    # Get track options
    track_opts = parse_options(file_n_opts[1:])

    # Check if all options are valid
    for k in track_opts.keys():
        if not k in valid_opts_list:
            fail("Option {} not valid for track type {}".format(k, track_type))

    # set default options and go to next track
    if not track_file:
        for k, v in track_opts.items():
            def_opts[k] = v
        continue

    # Try to guess options from file name
    guess_opts = {}
    if guess_opts_list:
        guess_opts = guess_options(track_file, guess_opts_list)

    # Set final track options using all available sources
    for k, v in def_opts.items() + guess_opts.items():
        if k in valid_opts_list and not track_opts.has_key(k):
            track_opts[k] = v

    track = {
        'type': track_type,
        'file': track_file,
        'opts': track_opts,
    }

    tracks.setdefault(track['type'], []).append(track)

# print repr(tracks) # FIXME

if not tracks.has_key('video'):
    fail('No video tracks')

if not tracks.has_key('audio'):
    fail('No audio tracks')

# -- print prepared options
tmpfile = codecs.getwriter('utf-8')(tempfile.NamedTemporaryFile(delete=False))
def uprint(*strings):
    for s in strings:
        tmpfile.write(s + '\n');

# global options
uprint('--output', dest_file)
uprint('--command-line-charset', 'utf-8')
if def_opts.has_key('filetitle'):
    uprint('--title', def_opts['filetitle'])
#uprint('--output-charset', 'utf-8')
#uprint('--default-language', def_lang)

# chapters
if tracks.has_key('chapters'):
    tt = tracks['chapters']
    if len(tt) > 1:
        fail("Only single chapters file allowed")
    t = tt[0]
    uprint('--chapter-charset', 'utf-8')
    print_options(t['opts'])
    uprint('--chapters', t['file'])

is_first_v_track = True
for t in tracks['video']:
    if is_first_v_track:
        print_options(t['opts'])
        uprint('--default-track', '-1:1')
        uprint(t['file'])
        is_first_v_track = False
    else:
        uprint('+' + t['file'])

is_first_a_track = True
for t in tracks['audio']:
    if is_first_a_track:
        uprint('--default-track', '-1:1')
    is_first_a_track = False
    print_options(t['opts'])
    uprint('--no-chapters')
    uprint(t['file'])

if tracks.has_key('subtitles'):
    for t in tracks['subtitles']:
        uprint('--default-track', '-1:0')
        print_options(t['opts'])
#        uprint('--sub-charset', '-1:ucs-2le')
        uprint(t['file'])

tmpfile.flush()
tmpfile.close()
os.system('mkvmerge @' + tmpfile.name)
os.unlink(tmpfile.name)

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
