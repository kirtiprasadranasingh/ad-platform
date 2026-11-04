# Metadata is delivered through Terraform outputs/app configuration, not duplicated
# into Key Vault. Application secrets are owned by the client's secret lifecycle.
# No data-plane secret writes during infrastructure bootstrap.
