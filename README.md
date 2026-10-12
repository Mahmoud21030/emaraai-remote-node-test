# EmaraAI RemoteNode test

Private staging repository for a bounded Windows integration test before purchasing a VPS.

The original kit is in EmaraAI-RemoteNode/. The manual Windows prerequisites workflow checks the runner browser and supplied script syntax. It does NOT establish end-to-end operation.

Next setup: store HUB_URL and a temporary TAILSCALE_AUTHKEY in repository Actions Secrets. Never commit node.json, browser profiles, cookies, passwords, or authentication keys. Interactive ChatGPT login and extension loading still require a separate bounded integration test.
