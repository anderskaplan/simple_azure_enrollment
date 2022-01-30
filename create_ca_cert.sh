# generate a private key and a custom root CA certificate according to the settings in create_ca_cert.cfg
# NOTE: make sure to edit the values in the req_distinguished_name section of the config file before running!
openssl req -x509 -config create_ca_cert.cfg -days 1826 -newkey rsa -keyout ca_private_key.pem -out ca_cert.pem
cp ca_cert.pem src
