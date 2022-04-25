# Tidbyt NHL Live App

 - Select a favorite team or shuffle through all teams.
 - Basic Game Info
   - Teams/Logos
   - Period
   - Time Remaining
   - Power Play / Empty Net Indication
 - Scheduled time of next game
 - Ticker that displays random game event:
   - Shots on Goal
   - Last Play
   - Last Goal Scored
   - Penalty Infraction Minutes
   - Power Play Goals
   - FaceOff Win Percentage
   - Hits
   - Blocks
   - Takeaways
   - Giveaways

# Use

  Requires: Pixlet version: v0.17.2 or higher

## Browser
  - `pixlet serve nhllive.star --watch`
  - Point browser to: `http://localhost:8080`


## Push to your Tidbyt
  - `export TEAMID=0` (0 for random team, or put in teamid from TEAMS_LIST in nhllive.star)
  - `pixlet render nhllive.star teamid=$TEAMID; pixlet push <TIDBIT DEVICE ID>  --api-token <TIDBIT API TOKEN> nhllive.webp;`
