EmaraAI remote node
===================

What it is
  The hub stays on your own PC. This kit runs the BROWSER side on another Windows machine (a VPS, a second PC):
  Chrome, the hub's extension and your ChatGPT session. All ChatGPT tabs, and the memory they need, live there.

What the machine needs (the kit installs nothing)
  1. Google Chrome.
  2. Tailscale, signed in with the SAME account as the hub's PC.
  3. On the hub's PC: Control Center > Settings > Remote access switched ON.

Start
  Double-click  Start-Node.cmd
  The first time it asks for the hub's private address (Control Center > Settings > Remote access) and opens Chrome.
  In that Chrome: sign in to ChatGPT once. If chrome://extensions does not list "EmaraAI Hub Connector",
  switch on Developer mode, press "Load unpacked" and choose the "extension" folder of this kit.
  On the hub's own PC close Chrome or switch the extension off: only one browser serves the hub at a time.

Options (run from a command prompt in this folder)
  Start-Node.cmd -RestartHours 5      restart Chrome every 5 hours to give its memory back
  Start-Node.cmd -Throttled           start Chrome without the switches that keep covered windows awake
  Start-Node.cmd -NoDevTools          do not open the inspector (DevTools) with every tab (it is opened by default)
  Start-Node.cmd -Hub <address>       use another hub address

Good to know
  - Your ChatGPT connectors belong to your ChatGPT account: nothing has to be connected again.
  - ChatGPT may ask for a human check when you sign in from a data-centre address. Only you can pass it.
  - Agents' own browser tools (opening a page of a program that runs on the hub's PC, page audits of localhost)
    run in THIS machine's Chrome and cannot reach "localhost" of the hub's PC.
  - After the hub was updated, build the kit again on the hub's PC and copy the "extension" folder over.
  - To go back: close this window and Chrome here, open Chrome on the hub's PC again.
