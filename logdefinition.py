#! /usr/bin/env python
# -*- coding: utf-8 -*-
import sys
import logging

logger = logging.getLogger(__name__)
for h in logger.handlers:
  logger.removeHandler(h)

h = logging.StreamHandler(sys.stdout)

FORMAT = '%(levelname)s %(asctime)s [%(funcName)s] %(message)s'
h.setFormatter(logging.Formatter(FORMAT))
logger.addHandler(h)

logging.basicConfig(filename='logfile/logger.log', level=logging.DEBUG)
