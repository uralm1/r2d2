#!/bin/sh
R2D2_PATH="/etc/r2d2"
exec svlogd $R2D2_PATH/<%= $log_dir %>
