#!/bin/bash
curl -fsSL https://raw.githubusercontent.com/onbrunosilva/zapmod-guardian/main/activator.sh | sed 's/\r//' > /tmp/zapmod.sh && sudo bash /tmp/zapmod.sh
