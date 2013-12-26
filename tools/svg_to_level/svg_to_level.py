#!/usr/bin/env python

import argparse
import itertools
import math
import re
import svg.path as svg
import xml.etree.ElementTree as etree

INKSCAPE_URI = "{http://www.inkscape.org/namespaces/inkscape}"
SVG_URI = "{http://www.w3.org/2000/svg}"

GROUP_TAG = SVG_URI + 'g'
PATH_TAG = SVG_URI + 'path'
RECT_TAG = SVG_URI + 'rect'
IMAGE_TAG = SVG_URI + 'image'
LABEL_ATTR = INKSCAPE_URI + 'label'

TRANSFORM_RE = re.compile(r'(\w+)\(([^\)]+)\)')
TRANSFORM_ARGS_RE = re.compile(r'([-\d\.e]+)')

def parse_transform(transform_string):
  if not transform_string: return None

  def to_matrix(piece):
    op, args = piece
    args = map(float, TRANSFORM_ARGS_RE.findall(args))
    if op == 'matrix': return args
    if op == 'translate': return [1.0, 0.0, 0.0, 1.0, args[0], args[1]]
    if op == 'scale': return [args[0], 0.0, 0.0, 0.0, args[1], 0.0]
    if op == 'rotate':
      ca = math.cos(args[0])
      sa = math.sin(args[0])
      rotation = [ca, -sa, 0.0, sa, ca, 0.0]
      if len(args) == 3:
        p = multiply_transforms(to_matrix('translate', args[1:2]), rotation)
        p = multiply_transforms(p, to_matrix('translate', [-args[1], -args[2]]))
        return p
      elif len(args) == 1:
        return rotation
      else:
        raise IOError(op + repr(args))

  transforms = itertools.imap(to_matrix, TRANSFORM_RE.findall(transform_string))
  return reduce(multiply_transforms, transforms)

def multiply_transforms(a, b):
  # [a0 a2 a4  [b0 b2 b4
  #  a1 a3 a5   b1 b3 b5
  #   0  0  1]   0  0  1]
  if not a: return b
  if not b: return a
  return [a[0] * b[0] + a[2] * b[1], a[1] * b[0] + a[3] * b[1],
          a[0] * b[2] + a[2] * b[3], a[1] * b[2] + a[3] * b[3],
          a[0] * b[4] + a[2] * b[5] + a[4], a[1] * b[4] + a[3] * b[5] + a[5]]

def transform_one(t, z):
  if not t: return z

  x, y = z.real, z.imag
  return (t[0] * x + t[2] * y + t[4]) + (t[1] * x + t[3] * y + t[5]) * 1j

def transform_many(t, zs):
  return itertools.imap(lambda z: transform_one(t, z), zs)

def path_to_polygon(path, opts):
  poly = []
  refine = opts['refinement']
  for segment in path:
    if isinstance(segment, svg.Line):
      poly.append(segment.start)
    else:
      num_verts = int(segment.length() / refine + .5)
      step = 1.0 / num_verts
      poly.extend((segment.point(x * step) for x in xrange(num_verts)))

  poly.append(path[-1].end)

  return poly

def rect_to_polygon(element, close):
  x, y = float(element.get('x')), float(element.get('y'))
  w, h = float(element.get('width')), float(element.get('height'))
  poly = [x + y * 1j, x + w + y * 1j, x + w + (y + h) * 1j, x + (y + h) * 1j]
  if close: poly.append(poly[0])
  return poly

def finalize_coords(xy, opts):
  dims = opts['dims']
  xy = ((p - dims * .5).conjugate() / dims.real for p in xy)
  return list(itertools.chain(*((x.real, x.imag) for x in xy)))

def parse_element(element, objects, transform, opts):
  transform = multiply_transforms(transform,
                                  parse_transform(element.get('transform')))
  if element.tag == GROUP_TAG:
    for child in element: parse_element(child, objects, transform, opts)
  elif element.tag == PATH_TAG:
    path = svg.parse_path(element.get('d'))
    poly = transform_many(transform, path_to_polygon(path, opts))
    objects.append({'xy': finalize_coords(poly, opts)})
  elif element.tag == RECT_TAG:
    poly = transform_many(transform, rect_to_polygon(element, True))
    objects.append({'xy': finalize_coords(poly, opts)})

def parse_svg(filename, opts):
  tree = etree.parse(filename)
  root = tree.getroot()
  width = float(root.get('width'))
  height = float(root.get('height'))
  opts['dims'] = width + height * 1j

  level = {}
  for layer_element in root.findall(GROUP_TAG):
    objects = []
    transform = parse_transform(layer_element.get('transform'))
    for child in layer_element: parse_element(child, objects, transform, opts)
    layer = {}
    layer['objects'] = objects
    level[layer_element.get(LABEL_ATTR).lower()] = layer

  return level

def to_lua(obj):
  if isinstance(obj, list):
    return '{' + ','.join(itertools.imap(to_lua, obj)) + '}'
  elif isinstance(obj, dict):
    return '{' + \
        ','.join((k + '=' + to_lua(v) for (k, v) in obj.iteritems())) + '}'
  else:
    return repr(obj)

def level_to_lua(level):
  return 'return ' + to_lua(level)

if __name__ == '__main__':
  parser = argparse.ArgumentParser(description='')
  parser.add_argument('filename', metavar='FILE', type=str, nargs=1,
      help='SVG file to convert')

  parser.add_argument('--refinement', type=float, nargs=1, default=18,
      help='Pixel distance between two consecutive points on a curve.')

  args = parser.parse_args()
  opts = { 'filename': args.filename[0], 'refinement': args.refinement }
  with open('path.lua', 'w') as f:
    f.write(level_to_lua(parse_svg(opts['filename'], opts)))
