{
  "idp_name": "${oidc_discovery_url}",
  "port": 9000,
  "client_config": [
    {
      "client_id": "foo",
      "client_secret": "bar",
      "redirect_uris": [
        "${oidc_redirect_url1}",
        "${oidc_redirect_url2}"
      ]
    }
  ],
  "claim_mapping": {
    "openid": [
      "sub",
      "groups",
      "name"
    ],
    "email": [
      "email",
      "email_verified"
    ],
    "profile": [
      "name",
      "nickname"
    ],
    "groups": [
      "groups"
    ]
  }
}