#!/usr/bin/env python

import argparse
import math
import re
import random
import svg.path as svg
import xml.etree.ElementTree as etree

from collections import defaultdict
from itertools import imap, izip, chain

INKSCAPE_URI = "{http://www.inkscape.org/namespaces/inkscape}"
SVG_URI = "{http://www.w3.org/2000/svg}"
SODIPODI_URI = "{http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd}"
XLINK_URI="{http://www.w3.org/1999/xlink}"

GROUP_TAG = SVG_URI + 'g'
PATH_TAG = SVG_URI + 'path'
RECT_TAG = SVG_URI + 'rect'
IMAGE_TAG = SVG_URI + 'image'
DESC_TAG = SVG_URI + 'desc'

LABEL_ATTR = INKSCAPE_URI + 'label'
SODITYPE_ATTR = SODIPODI_URI + 'type'
CX_ATTR = SODIPODI_URI + 'cx'
CY_ATTR = SODIPODI_URI + 'cy'
RX_ATTR = SODIPODI_URI + 'rx'
RY_ATTR = SODIPODI_URI + 'ry'
LINK_ATTR = XLINK_URI + 'href'

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
      ca, sa = math.cos(args[0]), math.sin(args[0])
      rotation = [ca, -sa, 0.0, sa, ca, 0.0]
      if len(args) == 3:
        p = multiply_transforms(to_matrix('translate', args[1:2]), rotation)
        p = multiply_transforms(p, to_matrix('translate', [-args[1], -args[2]]))
        return p
      elif len(args) == 1:
        return rotation
      else:
        raise IOError(op + repr(args))

  transforms = imap(to_matrix, TRANSFORM_RE.findall(transform_string))
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
  return imap(lambda z: transform_one(t, z), zs)

def dot(x, y): return x.real * y.real + x.imag * y.imag
def cross(x, y): return x.real * y.imag - x.imag * y.real
def angle(a, b, c):
  ab, cb = a - b, c - b
  return math.acos(dot(ab, cb) / math.sqrt(dot(ab, ab) * dot(cb, cb)))

def sort_poly(poly):
  a = sum(imap(lambda x: cross(*x), izip(poly, chain(poly[1:], poly[0:1]))))
  if a < 0: poly.reverse()

def path_to_polygon(path, opts):
  poly = []
  refine = opts['refinement']
  last_point = None
  for segment in path:
    if isinstance(segment, svg.Line):
      if segment != last_point: poly.append(segment.start)
    else:
      poly.extend(segment.subdivide(refine))
      last_point = segment.end

  poly.append(path[-1].end)
  while poly[-1] == poly[0]: poly.pop()

  area = 0.0

  simplified = [poly[0]]
  current_point = poly[1]

  for x in range(2, len(poly)):
      next_point = poly[x]
      prev_point = simplified[-1]
      u, v = next_point - current_point, prev_point - current_point
      new_area = abs(u.real * v.imag - u.imag * v.real) * .5
      if area + new_area > refine:
          area = 0.0
          simplified.append(current_point)
      else:
          area += new_area
      current_point = next_point

  simplified.append(poly[-1])

  return simplified

def rect_to_polygon(element, close):
  x, y = float(element.get('x')), float(element.get('y'))
  w, h = float(element.get('width')), float(element.get('height'))
  poly = [x + y * 1j, x + w + y * 1j, x + w + (y + h) * 1j, x + (y + h) * 1j]
  if close: poly.append(poly[0])
  return poly

def finalize_coords(xy):
  return list(chain(*((x.real, x.imag) for x in xy)))

def link_to_subclass(link):
  subclass = link[link.rfind('/') + 1:]
  subclass = subclass[:subclass.find('.')]
  return subclass


def triangle_check(v0, v1, v2):
  dot00, dot01, dot02 = dot(v0, v0), dot(v0, v1), dot(v0, v2)
  dot11, dot12 = dot(v1, v1), dot(v1, v2)

  invDenom = 1.0 / (dot00 * dot11 - dot01 * dot01)
  u = (dot11 * dot02 - dot01 * dot12) * invDenom
  v = (dot00 * dot12 - dot01 * dot02) * invDenom

  return (u >= 0.0) and (v >= 0.0) and (u + v < 1.0)

def is_ccw(a, b, c):
  ab, cb, ca = a - b, c - b, c - a
  return -a.real * cb.imag + b.real * ca.imag + c.real * ab.imag >= 0.0

def triangulate(vs):
  vs = list(vs)
  nv = len(vs)
  indices = range(nv)
  tris = set()
  while nv > 2:
    for bi in xrange(nv):
      ai, ci = (bi - 1) % nv, (bi + 1) % nv
      a, b, c = vs[ai], vs[bi], vs[ci]
      if is_ccw(a, b, c):
        ab, cb = a - b, c - b
        ear = True
        for j in xrange(nv):
          if j not in (ai, bi, ci) and triangle_check(cb, ab, vs[j] - b):
            ear = False
            break

        if ear:
          tris.add(tuple(sorted((indices[ai], indices[bi], indices[ci]))))
          del indices[bi]
          del vs[bi]
          nv = nv - 1
          break

  return tris

def refine_triangulation(vs, tris):
  tris_by_edge = defaultdict(set)

  def edges(t):
    return (((t[0], t[1]), 2), ((t[1], t[2]), 0), ((t[0], t[2]), 1))

  def remove_tri(t):
    tris.remove(t)
    for e in edges(t):
      tris_by_edge[e[0]].remove((t, e[1]))

  def add_tri(t):
    tris.add(t)
    for e in edges(t):
      tris_by_edge[e[0]].add((t, e[1]))

  for t in tris:
    for e in edges(t):
      tris_by_edge[e[0]].add((t, e[1]))

  # Delaunay flipping
  flipped = True
  while flipped:
    flipped = None
    for t1 in tris:
      for e, i1  in edges(t1):
        a, b, c = vs[t1[i1]], vs[e[0]], vs[e[1]]
        for t2, i2 in tris_by_edge[e]:
          if t1 is not t2:
            d = vs[t2[i2]]
            if angle(b, a, c) + angle(b, d, c) > math.pi:
              flipped = ((t1, t2), (t1[i1], t2[i2]), e)
              break
        if flipped: break
      if flipped: break

    if flipped:
      (t1, t2), (a, b), (c, d) = flipped
      remove_tri(t1)
      remove_tri(t2)
      add_tri(tuple(sorted((a, b, c))))
      add_tri(tuple(sorted((a, b, d))))

  # Polygon merging.
  polys = []
  while tris:
    seed_tri = random.sample(tris, 1)[0]
    poly = list(seed_tri)
    sort_poly(poly)
    remove_tri(seed_tri)

    merged = True
    while merged:
      merged = False
      for pbi in xrange(len(poly)):
        pai = (pbi - 1) % len(poly)
        pci = (pbi + 1) % len(poly)
        pdi = (pbi + 2) % len(poly)
        ai, bi, ci, di = poly[pai], poly[pbi], poly[pci], poly[pdi]

        if bi < ci: edge = (bi, ci)
        else: edge = (ci, bi)

        candidate_tri = tris_by_edge[edge]
        if len(candidate_tri) == 0: continue
        assert len(candidate_tri) == 1
        candidate_tri, tri_newi = iter(candidate_tri).next()

        newi = candidate_tri[tri_newi]
        a, b, c, d, newv = vs[ai], vs[bi], vs[ci], vs[di], vs[newi]
        if is_ccw(a, b, newv) and is_ccw(newv, c, d):
          remove_tri(candidate_tri)
          poly.insert(pci, newi)
          merged = True
          break

    polys.append(poly)
    print len(polys)

  return [reversed([vs[i] for i in poly]) for poly in polys]

def convexify(poly):
  return refine_triangulation(poly, triangulate(poly))

def parse_element(element, objects, transform, opts):
  obj = {}
  transform = multiply_transforms(transform,
                                  parse_transform(element.get('transform')))
  if element.tag == GROUP_TAG:
    for child in element:
      parse_element(child, objects, transform, opts)
    return

  if element.tag == PATH_TAG:
    if element.get(SODITYPE_ATTR) == 'arc':
      xy = float(element.get(CX_ATTR)) + float(element.get(CY_ATTR)) * 1j
      rx, ry = float(element.get(RX_ATTR)), float(element.get(RY_ATTR))

      xy = transform_one(transform, xy)
      if transform:
        rx *= transform[0]
        ry *= transform[3]
      radius = (rx + ry) * .5
      if max(rx, ry) / min(rx, ry) > 1.05:
        print 'W: Ellipse ' + element.get('id') + ' (%f, %f) will be ' \
              ' approximated as a circle with radius %f.' % (rx, ry, radius)

      obj['circle'] = finalize_coords([xy])
      obj['circle'].append(radius)
    else:
      path = svg.parse_path(element.get('d'))
      poly = list(transform_many(transform, path_to_polygon(path, opts)))
      sort_poly(poly)

      obj['poly'] = finalize_coords(poly)
      if 'triangulate' in opts:
        obj['convex'] = [finalize_coords(x) for x in convexify(poly)]
  elif element.tag == RECT_TAG or element.tag == IMAGE_TAG:
    poly = transform_many(transform, rect_to_polygon(element, False))

    obj['poly'] = finalize_coords(poly)
    if element.tag == RECT_TAG and 'triangulate' in opts:
      obj['convex'] = [obj['poly']]

    link = element.get(LINK_ATTR)
    desc = element.find(DESC_TAG)
    if link is not None: obj['subclass'] = link_to_subclass(link)
    if desc is not None: obj['script'] = desc.text

  if obj: objects.append(obj)

def parse_svg(filename, opts):
  tree = etree.parse(filename)
  root = tree.getroot()
  width = float(root.get('width'))
  height = float(root.get('height'))
  scale = opts['scale']
  global_transform = \
        [scale / width, 0.0, 0.0, -scale / width, -scale / 2, scale * height / width / 2]
  opts['dims'] = width + height * 1j

  level = {}
  for layer_element in root.findall(GROUP_TAG):
    label = layer_element.get(LABEL_ATTR).lower().strip()
    if label[0] == '#': continue
    label_components = label.split('|')
    name = label_components[0]
    directives = []
    if len(label_components) > 1:
      requested = (w.strip() for w in label_components[1].split(','))
      for d in requested:
        if d not in ['triangulate']:
          print 'W: Unrecognized directive "', d, '" in layer ', name
          continue
        directives.append(d)

    objects = []
    transform = parse_transform(layer_element.get('transform'))
    transform = multiply_transforms(global_transform, transform)
    for d in directives: opts[d] = True
    for child in layer_element: parse_element(child, objects, transform, opts)
    for d in directives: del opts[d]
    level[name] = objects

  return level

def to_lua(obj, depth):
  prefix = '  ' * depth
  prefixPlus = '  ' * (depth + 1)
  if isinstance(obj, list):
    return '{\n' + prefixPlus + (',\n' + prefixPlus).join( \
        imap(lambda x: to_lua(x, depth + 1) , obj)) + '\n' + prefix + '}'
  elif isinstance(obj, dict):
    return '{\n' + prefixPlus + (',\n' + prefixPlus).join( \
        (k + ' = ' + to_lua(v, depth + 1) for (k, v) in obj.iteritems())) + \
        '\n' + prefix + '}'
  else:
    return repr(obj)

def level_to_lua(level):
  return 'return ' + to_lua(level, 0)

if __name__ == '__main__':
  parser = argparse.ArgumentParser(description='')
  parser.add_argument('filename', metavar='FILE', type=str, nargs=1,
      help='SVG file to convert')

  parser.add_argument('--refinement', type=float, default=16,
      help='Pixel distance between two consecutive points on a curve.')

  parser.add_argument('--width', type=float, default=100.0,
      help='The width of the screen to which to scale the world coordinates.')

  args = parser.parse_args()
  opts = {
      'filename': args.filename[0],
      'refinement': args.refinement,
      'scale': args.width
  }

  with open('path.lua', 'w') as f:
    f.write(level_to_lua(parse_svg(opts['filename'], opts)))
    f.write('\n')
