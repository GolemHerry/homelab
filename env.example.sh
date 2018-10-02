#!/bin/bash

#
#
# Global Environment Variables
#
#

# postgres password for root
export DB_PASSWD=toor

# 
# 
# Application Specific Environment Variables

# Grafana related
export GF_SERVER_URL=https://monitor.example.com
export GF_EXPOSE_PORT=3000
export GF_ADMIN_USER=admin
export GF_ADMIN_PASSWD=admin
export GF_DB_PASSWD=admin
