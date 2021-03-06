# vim: set sts=2 ts=8 sw=2 tw=99 et:
import sys
from ambuild2 import run

# Simple extensions do not need to modify this file.

builder = run.PrepareBuild(sourcePath = sys.path[0])

builder.options.add_option('--sm-bin-path', type=str, dest='sm_bin_path', default=None,
                       help='Path to compiled SourceMod')
builder.options.add_option('--enable-debug', action='store_const', const='1', dest='debug',
                       help='Enable debugging symbols')
builder.options.add_option('--enable-optimize', action='store_const', const='1', dest='opt',
                       help='Enable optimization')

builder.Configure()
