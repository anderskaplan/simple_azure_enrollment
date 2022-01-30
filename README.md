# Simple Azure Enrollment
This is an Azure web function to sign certificate requests with a CA certificate. Almost, but not quite, 
an [EST server](https://datatracker.ietf.org/doc/html/rfc7030).

Based on [Kevin Saye's "super simple CA" project](https://kevinsaye.wordpress.com/2020/06/03/using-openssl-and-azure-functions-as-a-certificate-authority-for-azure-iot-devices-and-iot-edge/).

## Background
An Internet-connected device provides an API over https. Https (or actually, TLS, which https runs on top of)
requires that the device have a certificate which it can provide to clients when a secure connection is established. The device certificate is public, but it is created from a secret private key, which must also be available on the device. The device certificate must be signed with a CA (Certification Authority) certificate which is trusted by the client, or else the client will not accept it.

It is possible that more than one CA certificate is needed to establish a chain of trust between the CA certificate used to sign the device certificate, and a root CA certificate known to the client. In that case, those certificates may also be provided in a "certificate chain file".

A typical https key/certificate setup looks like this (example from Apache/mod_ssl):
- certificate file: certificate.crt (public; signed by CA)
- certificate chain file: ca_bundle.crt (public; optional)
- certificate key file: private.key

## Design considerations
Each device should have its own, unique device certificate and private key. There are future use cases where it will be very useful to be able to authenticate the devices. This should be set up automatically as part of the device deployment sequence, or when devices are upgraded in the field.

We prefer to use a custom root CA certificate instead of purchasing a certificate. Trust is not a problem, because we have control over all API clients and can install the custom root CA certificate on them. One issue with purchased CA certificates is that they expire after a bit over a year, and these devices might be disconnected from the Internet for longer than that. (Switching to a purchased CA certificate would not make much of a difference for the overall workflow.)

We want to avoid secrets in source control.

## Workflow
This is a quite cryptography heavy workflow, but fortunately the well known [openssl](https://linux.die.net/man/1/openssl) program can do most of the work for us. The basic workflow follows [this article](https://stackoverflow.com/a/68854352).

1. Create a custom root CA certificate and private key:

   `openssl req -x509 -days 365 -newkey rsa:4096 -keyout ca_private_key.pem -out ca_cert.pem`

2. Create a private key for the device and a certificate request -- this will become the device certificate once signed with the CA certificate:

   `openssl req -new -newkey rsa:4096 -keyout my_private_key.pem -out my_cert_req.pem`

3. Sign the certificate request and turn it into a device certificate:

   `openssl x509 -req -in my_cert_req.pem -days 365 -CA ca_cert.pem -CAkey ca_private_key.pem -CAcreateserial -out my_signed_cert.pem`

Unfortunately the workflow will not be quite as straightforward in reality, since the private key for the custom root CA certificate will not be available on the devices. Instead, the approach taken here is to provide an enrollment service which can be accessed from the devices and run step 3 for them.

The openssl command invocations are also a bit simplified. For example, expiry dates will need to be set more carefully. Publicly rooted CA certificates now have a maximum lifetime of [398 days](https://thehackernews.com/2020/09/ssl-tls-certificate-validity-398.html), but the devices will need longer certificate lifetimes since they may not have the internet connectivity needed to renew certificates. Certificates issued by user-added or administrator-added root CAs are not affected by the shortened lifetime rules.

The private key for the root CA certificate is stored as a secret in an [Azure key vault](https://docs.microsoft.com/en-us/azure/key-vault/general/). The enrollment service is an [Azure web function](https://docs.microsoft.com/en-us/azure/azure-functions/functions-reference-node) which is given access to the private key through a [managed identity](https://azure.microsoft.com/en-us/blog/keep-credentials-out-of-code-introducing-azure-ad-managed-service-identity/).

The private keys will be well protected with this setup. A somewhat weak spot is the protection of the enrollment service. Ideally there could a something on the device which can be used to authenticate to the enrollment service automatically.
