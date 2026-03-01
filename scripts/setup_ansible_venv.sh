#!/bin/bash
# Setup Python virtual environment for Ansible playbooks

python3 -m venv ansible_venv
source ansible_venv/bin/activate
pip install --upgrade pip
pip install ansible ansible-lint jinja2
echo "✓ Ansible environment ready"
