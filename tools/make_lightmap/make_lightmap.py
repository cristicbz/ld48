#!/usr/bin/env python

import argparse
import itertools
import math
from PIL import Image

if __name__ == '__main__':
  parser = argparse.ArgumentParser(description='')
  parser.add_argument('filename', metavar='FILE', type=str, help='Output file.')
  parser.add_argument('--size', type=int, default=256, help='The size of the map.')
  parser.add_argument('--falloff', type=float, default=1, help = '')
  parser.add_argument('--sharp',
      type=float, default=0.01, help='The quadratic attenuation factor.')

  args = parser.parse_args()
  size = args.size

  img = Image.new('RGB', (size, size))
  pixels = img.load()
  #1 / (a + b*d + c*d^2)
  #  = 1, d = m => ch * m + c*m^2 = 1 - a - zm => c = (1 - a -zm) / (hm + m^2)
  #  = f, d = h => 1 / (a + bh + ch^2) = f => bh + ch^2 = (1 / f - a) =>
  #  => b = (1 / f - 1 - ch^2) / h = (1 / f - 1) / h - ch

  h = size * .5
  m = args.falloff * h
  e = 129
  a = (e - 1) / ((h - m) * (h - m))

  for i in xrange(size):
    for j in xrange(size):
      dx, dy = (i - size / 2), (j - size / 2)
      d = max(m, math.sqrt(dx * dx + dy * dy))
      g = int(255.0 / (a * (d - m) * (d - m) + 1))
      pixels[i , j] = (g, g, g)

  img.save(args.filename, 'png')

