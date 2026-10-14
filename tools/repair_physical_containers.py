"""Repair physical-container consumption verified against B42.21 and B41 source.

Partial fluid consumption and kept water providers are never inferred or changed.
"""
import argparse
from pathlib import Path

from repair_food_counts import apply

MANIFEST = Path(__file__).with_name('physical_container_migrations.json')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    apply(parser.parse_args().check, MANIFEST)
