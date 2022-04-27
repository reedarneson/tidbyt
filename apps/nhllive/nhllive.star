"""
Applet: NHL Live
Summary: Live updates of NHL games
Description: Displays live game stats or next scheduled NHL game information
Author: Reed Arneson
"""


load("render.star", "render")
load("http.star", "http")
load("encoding/base64.star", "base64")
load("time.star", "time")
load("encoding/json.star", "json")
load("schema.star", "schema")
load("random.star", "random")
load("cache.star", "cache")

# Constants
DEFAULT_LOCATION = """
{
	"lat": "39.7392",
	"lng": "104.9903",
	"description": "Denver, CO, USA",
	"locality": "Denver",
	"place_id": "ChIJzxcfI6qAa4cR1jaKJ_j0jhE",
	"timezone": "America/Denver"
}
"""

FONT_STYLE = "CG-pixel-3x5-mono"
FONT_COLOR_EVEN = "#FFFFFF"
FONT_COLOR_POWERPLAY = "#59e9ff"
FONT_COLOR_EMPTYNET = "#eb4c46"
FONT_COLOR_POWERPLAY_EMPTYNET = "#a838d1"

CACHE_LOGO_SECONDS = 86400
CACHE_GAME_SECONDS = 3600
CACHE_UPDATE_SECONDS = 10

BASE_URL = "https://statsapi.web.nhl.com"
BASE_IMAGE_URL="https://a.espncdn.com/combiner/i?img=/i/teamlogos/nhl/500/{}.png&scale=crop&cquality=40&location=origin&w=80&h=80"

NHL_LOGO = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAABAAAAATCAYAAACZZ43PAAAAAXNSR0IArs4c6QAABCdJREFUOE9jZIACAQEBBQMjo4AD+/ZNgImpamj4yElLf9y7d
+9hmJiLu3vBmZMnN3z48OEBSIwRJhESEpJibG4RxM/Nda+qqmpNWGSkyveff6JsLUwZPnz4sKytre12eHRsKC8vr9KLJ4/WLVmyZA7cAJDtFZU1M2
bNnqkmJSX5UUlR8cejR48ZhYSERJlZWBj+/v71hpOL69/ly5d5ONjZmVNSUx+VlZZmgFzBGBMT06enp2e2YuUqDk8fP+NvX748YGNjVZCXl2OYMmn
iLZAtlZVVap8+fWLwDwhguHHjBkNzU+NZb1/fT7t27bnAWF1dXbNj1+7wkPBIna7Wpg8MDAwCMG/BaGVlld/tHR0MmRnpN96+fSu7es1agdramgvi
UjJrGQUEBAwsrW0namtr282dPRNdL4O/vz+Dq6vbtcmTJ72/efOmNUhBS0srw5Zt2w8dP3o4HhyINnaOB9LSUuzzc3NQDAApvHbj+pETx479bmpuk
Y6JjlIDKZg3fwHDrFmzD27ftsUBbICtg+OBvNxc+7SUZLABPDw87yZNniI0deqUA2fPnHGYNGnyRZD43LlzXr1//0GkobHRcOOG9QcXLFjgAPaCgb
FJn7+vj0FTY6Ogqqrq6+KS0n8F+Xkf5sydx9jc1Pg6OzuHB2TAipUrfmhraQm4uXuoL1wwf//mzZuLGKura2s2b9kUrKenJygmJsYvKyt7va+3l83
S2vqLr7ePwPHjxz5aWlrxV1VV8vb3TxSZPGXSLUkJCR4mZuYPf/4xbGJsb2/vOHX6tEd2do7+rJkz96tpqLPu2bWLUU5B4Q/IgLy8XH19fYML+QUF
BjnZWbe+ffumJiAg8NDB0en3+0+fFzJOmz59wamTJ3UOHDjA/PHjR4MlS5fdUlJSkqhvqD//6MEDZikpKV7/gEC9gvy8j8hRHBkdw/D81et5jLNmz
albsGCex6tXr+Tevn0rDQqwzVu3fLh3587/pORkyWNHj7Jt3bpVETl6REREbqqoabDz8guuZOzs7Ezcvn17WGBQsH1DfR1nTk7O0Xnz5olPnjJVob
am+v6zZ89U0RNHbGLy17OnTx3k4+PfDYoFgdLS0t5jx45rKyjIi1+8ePFlcUmpeUpy0qd///7xoWv2CQh8cfP69YfaOroP1q9ZlQFOB87OzrbOLi7
ZC+bPl66trbMBpfujR4/c37t3L+e/f//+6+kbPtfR01P5/fcf375d23f7+gf83LtrZ9e5c+cOw7NzcHCwnq6eQdHxU6cUP394JywhIcklISmp+PPX
L4bXr17e//L58zcJcck3hkZGD/YeOtC3Y9OmSyjlAVLBYmBgZGrCy8erx8bOYWRubMDAysp65MqVK3fWrl175sOHDxeQvQV3AUYuYmBgMDc3j5CSk
mJYv379CmzyIDEA/Aa7ZTTsFScAAAAASUVORK5CYII=
""")

# Some teams have abbr_fix due to inconsistent pattern by logo scrape source
TEAMS_LIST = {
    1: {'name': 'New Jersey Devils', 'abbreviation': 'NJD'}, 
    2: {'name': 'New York Islanders', 'abbreviation': 'NYI'}, 
    3: {'name': 'New York Rangers', 'abbreviation': 'NYR'}, 
    4: {'name': 'Philadelphia Flyers', 'abbreviation': 'PHI'}, 
    5: {'name': 'Pittsburgh Penguins', 'abbreviation': 'PIT'}, 
    6: {'name': 'Boston Bruins', 'abbreviation': 'BOS'}, 
    7: {'name': 'Buffalo Sabres', 'abbreviation': 'BUF'}, 
    8: {'name': 'Montréal Canadiens', 'abbreviation': 'MTL'}, 
    9: {'name': 'Ottawa Senators', 'abbreviation': 'OTT'}, 
    10: {'name': 'Toronto Maple Leafs', 'abbreviation': 'TOR'}, 
    12: {'name': 'Carolina Hurricanes', 'abbreviation': 'CAR'}, 
    13: {'name': 'Florida Panthers', 'abbreviation': 'FLA'}, 
    14: {'name': 'Tampa Bay Lightning', 'abbreviation': 'TBL', "abbr_fix": "TB"}, 
    15: {'name': 'Washington Capitals', 'abbreviation': 'WSH'}, 
    16: {'name': 'Chicago Blackhawks', 'abbreviation': 'CHI'}, 
    17: {'name': 'Detroit Red Wings', 'abbreviation': 'DET'}, 
    18: {'name': 'Nashville Predators', 'abbreviation': 'NSH'}, 
    19: {'name': 'St. Louis Blues', 'abbreviation': 'STL'}, 
    20: {'name': 'Calgary Flames', 'abbreviation': 'CGY'}, 
    21: {'name': 'Colorado Avalanche', 'abbreviation': 'COL'}, 
    22: {'name': 'Edmonton Oilers', 'abbreviation': 'EDM'}, 
    23: {'name': 'Vancouver Canucks', 'abbreviation': 'VAN'}, 
    24: {'name': 'Anaheim Ducks', 'abbreviation': 'ANA'}, 
    25: {'name': 'Dallas Stars', 'abbreviation': 'DAL'}, 
    26: {'name': 'Los Angeles Kings', 'abbreviation': 'LAK', "abbr_fix": "LA"},
    28: {'name': 'San Jose Sharks', 'abbreviation': 'SJS', "abbr_fix": "SJ"},
    29: {'name': 'Columbus Blue Jackets', 'abbreviation': 'CBJ'},
    30: {'name': 'Minnesota Wild', 'abbreviation': 'MIN'}, 
    52: {'name': 'Winnipeg Jets', 'abbreviation': 'WPG'}, 
    53: {'name': 'Arizona Coyotes', 'abbreviation': 'ARI'}, 
    54: {'name': 'Vegas Golden Knights', 'abbreviation': 'VGK'}, 
    55: {'name': 'Seattle Kraken', 'abbreviation': 'SEA'}
}

# Main App
def main(config):
    game_data = None

     # Get timezone and set today date
    timezone = get_timezone(config)
    now = time.now().in_location(timezone)
    today = now.format("2006-1-2").upper()

    # Grab teamid from our schema 
    config_teamid = config.get("teamid") or 0
    config_teamid = int(config_teamid)

    if config_teamid == 0:
        config_teamid = get_random_team()

    # See if there is any scheduled game
    if config_teamid in TEAMS_LIST.keys():
        team = TEAMS_LIST[config_teamid]['name']
    else: 
        team = config_teamid


    # Check our game info cache first
    print("Grabbing Game for team: %s" % team)
    goals_away, goals_home, update, game_time, game_period, is_pp_away, is_pp_home, is_empty_away, is_empty_home = get_game_update_cached(config_teamid)
    teamid_away, teamid_home, game_url = get_game(today, config_teamid)

    # If not in cache, grab new info (or error out)
    if goals_away == None or goals_home == None or update == None or game_time == None or game_period == None or is_pp_away == None or is_pp_home == None or is_empty_away == None or is_empty_home == None:
        print("  - CACHE: No Game Info found for teamid %s" % config_teamid )

        # No Game URL found
        if game_url != None:
            game_data = get_game_data(game_url)
            print("  - URL: %s" % game_url)
        else:
            print("ERROR: No Game URL")

        # No Games Found, whomp whomp display
        if game_data == None:
            print("ERROR: No Game Data")
            return render.Root(
                child = render.Box(
                    child = render.Column(
                        expanded=True,
                        main_align="space_around",
                        cross_align="center",
                        children = [
                            render.Image(
                                src=NHL_LOGO,
                                width=20,
                                height=20,
                            ),
                            render.Text(
                                content="No Games :(",
                                font=FONT_STYLE,
                                color="#ababab",
                            )
                        ],
                    ),
                ),
            )
        # Grab fresh info
        goals_away, goals_home, update, game_time, game_period, is_pp_away, is_pp_home, is_empty_away, is_empty_home = get_game_update(game_data, config, config_teamid)
    else:
        print("  - CACHE: Game Info found for teamid %s" % config_teamid)

    # We have a Game, let's get some info!
    logo_away = str(get_team_logo(teamid_away))
    logo_home = str(get_team_logo(teamid_home))

    # PowerPlay/EmptyNet Color Change
    score_color_away = get_score_color(is_pp_away, is_empty_away)
    score_color_home = get_score_color(is_pp_home, is_empty_home)

    return render.Root(
        child = render.Column(
            children = [
                render.Row(
                    expanded=True,
                    main_align="space_around",
                    cross_align="center",
                    children = [
                        render.Column(
                            cross_align="center",
                            children = [
                                render.Image(width=18, height=18, src=logo_away),
                                render.Text(
                                    content=TEAMS_LIST[teamid_away]['abbreviation'] + " "  + goals_away,
                                    font=FONT_STYLE,
                                    color=score_color_away,
                                ),
                            ],
                        ),
                        render.Column(
                            cross_align="center",
                            main_align="space evenly",
                            children = [
                                render.Text(
                                    content=game_time,
                                    font=FONT_STYLE,
                                    color="#ffbe0a",
                                ),
                                render.Text(
                                    content='vs',
                                    font=FONT_STYLE,
                                    color="#525252",
                                ),
                                render.Text(
                                    content=game_period,
                                    font=FONT_STYLE,
                                    color="#ffbe0a",
                                ),
                            ]
                        ),

                        render.Column(
                            cross_align="center",
                            children = [
                                render.Image(width=18, height=18, src=logo_home),
                                render.Text(
                                    content=goals_home + " " + TEAMS_LIST[teamid_home]['abbreviation'],
                                    font=FONT_STYLE,
                                    color=score_color_home,
                                ),
                            ],
                        ),
                    ],
                ),
                render.Box(
                    height=9,
                    child = render.Row(
                            expanded=True,
                            main_align="end",
                            children = [
                                render.Marquee(
                                    offset_start=16,
                                    offset_end=16,
                                    width=64,
                                    child=render.Text(
                                        content=update,
                                        font=FONT_STYLE,
                                        color="#ffbe0a",
                                    ),
                                ),
                            ]
                        ),
                ),
            ]
        )
    )

def get_team_logo(teamId):
    # check cache for logo
    cache_key = "logo_" + str(int(teamId))
    logo = cache.get(cache_key)

    if logo == None:
        print("  - CACHE: No key %s" % cache_key )

        # janky abbrevations fix
        if 'abbr_fix' in TEAMS_LIST[teamId]:
            abbr = TEAMS_LIST[teamId]['abbr_fix']
        else:
            abbr = TEAMS_LIST[teamId]['abbreviation']
        
        url = BASE_IMAGE_URL.format(abbr)
        response = http.get(url)
        
        if response.status_code != 200:
            logo = NHL_LOGO
        else:
            logo = response.body()
            cache.set(cache_key, logo, ttl_seconds=CACHE_LOGO_SECONDS)
    else:
        print("  - CACHE: Image Found for %s" % cache_key)
    return logo

# returns today's current or next-schedule game for team - including opponent and live game feed url
def get_game(date,teamId):

    cache_key_away = "game_" + str(teamId) + "_away" 
    cache_key_home = "game_" + str(teamId) + "_home" 
    cache_key_url = "game_" + str(teamId) + "_url" 
  
    teamid_away = cache.get(cache_key_away) or None
    teamid_home = cache.get(cache_key_home) or None
    game_url = cache.get(cache_key_url) or None

    if teamid_away == None or teamid_home == None or game_url == None:
        print("  - CACHE: No Game URL found for team %s" %teamId)
        url = BASE_URL+"/api/v1/schedule?startDate="+date+"&teamId="+str(teamId)
        response = http.get(url)

        if response.status_code == 200:
            response = response.json()

            # Check next scheduled
            if response['totalGames'] == 0:
                response = get_next_game(teamId)
            
            if response['totalGames'] > 0:
                teamid_away = int(response['dates'][0]['games'][0]['teams']['away']['team']['id'])
                teamid_home = int(response['dates'][0]['games'][0]['teams']['home']['team']['id'])
                game_url = response['dates'][0]['games'][0]['link']

                cache.set(cache_key_away, str(teamid_away), ttl_seconds=CACHE_GAME_SECONDS)
                cache.set(cache_key_home, str(teamid_home), ttl_seconds=CACHE_GAME_SECONDS)
                cache.set(cache_key_url, game_url, ttl_seconds=CACHE_GAME_SECONDS)

    else:
        print("  - CACHE: Found game for team %s" %teamId)
            
    return int(teamid_away), int(teamid_home), game_url

# looks up the next game for a team
def get_next_game(teamId):
    url = BASE_URL+"/api/v1/teams?expand=team.schedule.next&teamId="+str(teamId)
    response = http.get(url)

    # We couldn't get a game
    if response.status_code != 200:
        return {'totalGames':0}

    response = response.json()
    return response['teams'][0]['nextGameSchedule']

# return live game data
def get_game_data(game_url):
    response = http.get(BASE_URL+game_url)
    if response.status_code != 200:
        return None
    return response.json()

# pull from cache if exists
def get_game_update_cached(teamid):
    goals_away = cache.get("game_" + str(teamid) + "_goals_away") or None
    goals_home = cache.get("game_" + str(teamid) + "_goals_home") or None
    game_time = cache.get("game_" + str(teamid) + "_game_time") or None
    game_period = cache.get("game_" + str(teamid) + "_game_period") or None
    is_pp_away = cache.get("game_" + str(teamid) + "_is_pp_away") or None
    is_pp_home = cache.get("game_" + str(teamid) + "_is_pp_home") or None
    is_empty_away = cache.get("game_" + str(teamid) + "_is_empty_away") or None
    is_empty_home = cache.get("game_" + str(teamid) + "_is_empty_home") or None
    update = cache.get("game_" + str(teamid) + "_update") or None

    return str(goals_away), str(goals_home), update, game_time, game_period, is_pp_away, is_pp_home, is_empty_away, is_empty_home

# collection function to get current score, time, and other random updates
def get_game_update(game, config, teamid):
    goals_away,goals_home = get_current_score(game)
    game_time = ""
    game_period = ""
    is_pp_away = ""
    is_pp_home = ""
    is_empty_away = ""
    is_empty_home = ""

    opts = []
    opt = ""
    update = ""
    
    # If we have a live game, let's get some live game info
    if game['gameData']['status']['abstractGameState'] == "Live":
        game_time, game_period = get_current_live_game_time(game)

        # is there a PP or empty net?
        is_pp_away = game['liveData']['linescore']['teams']['away']['powerPlay']
        is_pp_home = game['liveData']['linescore']['teams']['home']['powerPlay']
        is_empty_away = game['liveData']['linescore']['teams']['away']['goaliePulled']
        is_empty_home = game['liveData']['linescore']['teams']['home']['goaliePulled']

        # Add stats to the optionlist as desired
        if config.bool("sog", True):
            opts.append("SOG")
        if config.bool("play", True):
            opts.append("PLAY")
        if config.bool("pen", True):
            opts.append("PEN")
        if config.bool("ppg", True):
            opts.append("PPG")
        if config.bool("fo", True):
            opts.append("FO")
        if config.bool("pim", True):
            opts.append("PIM")
        if config.bool("hit", True):
            opts.append("HIT")
        if config.bool("blk", True):
            opts.append("BLK")
        if config.bool("take", True):
            opts.append("TAKE")
        if config.bool("give", True):
            opts.append("GIVE")

        # No reason to pull this info unless there has been a goal scored
        if (goals_away > 0 or goals_home > 0) and config.bool("lg", True):
            opts.append("LG")

    # If not live game, just get basic game info (results or next game time)
    else:
        opts.append("INFO")

    print("  - OPTS: %s" % opts)
    # randomly choose what update to show
    if len(opts) > 0:
        opt = opts[random.number(0, len(opts)-1)]
        print("  - OPT: %s" % opt)

    if opt == "INFO":
        update = get_game_info(game, config)
    elif opt == "SOG":
        update = get_sog(game)
    elif opt == "LG":
        update = get_latest_goal(game)
    elif opt == "PLAY":
        update = get_last_play(game)
    elif opt == "PEN":
        update = get_penalties(game)
    elif opt == "PIM":
        update = get_pim(game)
    elif opt == "PPG":
        update = get_ppg(game)
    elif opt == "FO":
        update = get_faceoffs(game)
    elif opt == "HIT":
        update = get_hits(game)
    elif opt == "BLK":
        update = get_blocks(game)
    elif opt == "TAKE":
        update = get_takeaways(game)
    elif opt == "GIVE":
        update = get_giveaways(game)
    
    print("  - Update: %s" % update)

    # Set into the cache
    cache.set("game_" + str(teamid) + "_goals_away", str(goals_away), ttl_seconds = CACHE_UPDATE_SECONDS) 
    cache.set("game_" + str(teamid) + "_goals_home", str(goals_home), ttl_seconds = CACHE_UPDATE_SECONDS)
    cache.set("game_" + str(teamid) + "_game_time", str(game_time), ttl_seconds = CACHE_UPDATE_SECONDS)
    cache.set("game_" + str(teamid) + "_game_period", str(game_period), ttl_seconds = CACHE_UPDATE_SECONDS)
    cache.set("game_" + str(teamid) + "_is_pp_away", str(is_pp_away), ttl_seconds = CACHE_UPDATE_SECONDS)
    cache.set("game_" + str(teamid) + "_is_pp_home", str(is_pp_home), ttl_seconds = CACHE_UPDATE_SECONDS) 
    cache.set("game_" + str(teamid) + "_is_empty_away", str(is_empty_away), ttl_seconds = CACHE_UPDATE_SECONDS)
    cache.set("game_" + str(teamid) + "_is_empty_home", str(is_empty_home), ttl_seconds = CACHE_UPDATE_SECONDS)
    cache.set("game_" + str(teamid) + "_update", str(update), ttl_seconds = CACHE_UPDATE_SECONDS)

    return str(goals_away), str(goals_home), update, game_time, game_period, is_pp_away, is_pp_home, is_empty_away, is_empty_home

# Get scheduled/finished game info
def get_game_info(game, config):
    if game['gameData']['status']['abstractGameState'] == "Final":
        if game['liveData']['linescore']['currentPeriodOrdinal'] == "SO":
            return "    FINAL/SO"
        if game['liveData']['linescore']['currentPeriodOrdinal'] == "OT":
            return "    FINAL/OT"
        return "      FINAL"
    elif game['gameData']['status']['abstractGameState'] == "Preview":
        game_schedule = time.parse_time(game['gameData']['datetime']['dateTime'])
        game_schedule = game_schedule.in_location(get_timezone(config))
        game_schedule = game_schedule.format("Mon, Jan 2 @ 3:04PM")
        return str("Next Game: " + game_schedule)
    else:
       return ""

# get game time and period
def get_current_live_game_time(game):
    if game['gameData']['status']['abstractGameState'] == "Live":
        period = game['liveData']['linescore']['currentPeriodOrdinal']
        currentPeriodTimeRemaining = game['liveData']['linescore']['currentPeriodTimeRemaining']
        return currentPeriodTimeRemaining, period
    else:
        return ""

# get the current score
def get_current_score(game):
    score_away = int(game['liveData']['linescore']['teams']['away']['goals'])
    score_home = int(game['liveData']['linescore']['teams']['home']['goals'])
    return score_away, score_home

# get team abbreviations for away/home
def get_current_teams(game):
    team_away = game['liveData']['linescore']['teams']['away']['team']['abbreviation']
    team_home = game['liveData']['linescore']['teams']['home']['team']['abbreviation']
    return team_away, team_home

# return info of whoever scored last
def get_latest_goal(game):
    scoringPlays = game['liveData']['plays']['scoringPlays']
    if len(scoringPlays) > 0:
        last_goal = int(scoringPlays[-1])
        period = game['liveData']['plays']['allPlays'][last_goal]['about']['ordinalNum']
        time = game['liveData']['plays']['allPlays'][last_goal]['about']['periodTime'] 
        description = game['liveData']['plays']['allPlays'][last_goal]['result']['description']
        return "LG: " + description + " @ " + time + " in " + period
    else:
        return "LG: Play Data Not Available Yet"

# whatever last play happened
def get_last_play(game):
    play = game['liveData']['plays']['currentPlay']['result']['description']
    period = game['liveData']['plays']['currentPlay']['about']['ordinalNum']
    time = game['liveData']['plays']['currentPlay']['about']['periodTime'] 
    return play + " @ " + time + " in " + period 

# current num of penalites
def get_penalties(game):
    ppo_away = int(game['liveData']['boxscore']['teams']['away']['teamStats']['teamSkaterStats']['powerPlayOpportunities'])
    ppo_home = int(game['liveData']['boxscore']['teams']['home']['teamStats']['teamSkaterStats']['powerPlayOpportunities'])
    team_away, team_home = get_current_teams(game)
    return "PEN: " + team_away + '-' + str(ppo_home) + " " + team_home + '-' + str(ppo_away)

# get shots on goal stats
def get_sog(game):
    sog_away = int(game['liveData']['boxscore']['teams']['away']['teamStats']['teamSkaterStats']['shots'])
    sog_home = int(game['liveData']['boxscore']['teams']['home']['teamStats']['teamSkaterStats']['shots'])
    team_away, team_home = get_current_teams(game)
    return "SOG: " + team_away + "-" + str(sog_away) + " " + team_home + "-" + str(sog_home)

# current penality minutes
def get_pim(game):
    pim_away = int(game['liveData']['boxscore']['teams']['away']['teamStats']['teamSkaterStats']['pim'])
    pim_home = int(game['liveData']['boxscore']['teams']['home']['teamStats']['teamSkaterStats']['pim'])
    team_away, team_home = get_current_teams(game)
    return "PIM: " + team_away + "-" + str(pim_away) + " " + team_home + "-" + str(pim_home)

# get current ppg / opportunities
def get_ppg(game):
    ppg_away = int(game['liveData']['boxscore']['teams']['away']['teamStats']['teamSkaterStats']['powerPlayGoals'])
    ppg_home = int(game['liveData']['boxscore']['teams']['home']['teamStats']['teamSkaterStats']['powerPlayGoals'])
    ppo_away = int(game['liveData']['boxscore']['teams']['away']['teamStats']['teamSkaterStats']['powerPlayOpportunities'])
    ppo_home = int(game['liveData']['boxscore']['teams']['home']['teamStats']['teamSkaterStats']['powerPlayOpportunities'])
    team_away, team_home = get_current_teams(game)
    return "PPG: " + team_away + "-" + str(ppg_away) + "/" + str(ppo_away) + " " + team_home + "-" + str(ppg_home) + "/" + str(ppo_home)

# get faceoff percentages
def get_faceoffs(game):
    fo_away = game['liveData']['boxscore']['teams']['away']['teamStats']['teamSkaterStats']['faceOffWinPercentage']
    fo_home = game['liveData']['boxscore']['teams']['home']['teamStats']['teamSkaterStats']['faceOffWinPercentage']
    team_away, team_home = get_current_teams(game)
    return "Faceoffs: " + team_away + "-" + str(fo_away) + "%" + " " + team_home + "-" + str(fo_home) + "%"

# get hit stats
def get_hits(game):
    hits_away = int(game['liveData']['boxscore']['teams']['away']['teamStats']['teamSkaterStats']['hits'])
    hits_home = int(game['liveData']['boxscore']['teams']['home']['teamStats']['teamSkaterStats']['hits'])
    team_away, team_home = get_current_teams(game)
    return "HITS: " + team_away + "-" + str(hits_away) + " " + team_home + "-" + str(hits_home)

# get block stats
def get_blocks(game):
    blocks_away = int(game['liveData']['boxscore']['teams']['away']['teamStats']['teamSkaterStats']['blocked'])
    blocks_home = int(game['liveData']['boxscore']['teams']['home']['teamStats']['teamSkaterStats']['blocked'])
    team_away, team_home = get_current_teams(game)
    return "Blocks: " + team_away + "-" + str(blocks_away) + " " + team_home + "-" + str(blocks_home)

# get takeaway stats
def get_takeaways(game):
    take_away = int(game['liveData']['boxscore']['teams']['away']['teamStats']['teamSkaterStats']['takeaways'])
    take_home = int(game['liveData']['boxscore']['teams']['home']['teamStats']['teamSkaterStats']['takeaways'])
    team_away, team_home = get_current_teams(game)
    return "Takeaways: " + team_away + "-" + str(take_away) + " " + team_home + "-" + str(take_home)

# get giveaway stats
def get_giveaways(game):
    give_away = int(game['liveData']['boxscore']['teams']['away']['teamStats']['teamSkaterStats']['giveaways'])
    give_home = int(game['liveData']['boxscore']['teams']['home']['teamStats']['teamSkaterStats']['giveaways'])
    team_away, team_home = get_current_teams(game)
    return "Giveaways: " + team_away + "-" + str(give_away) + " " + team_home + "-" + str(give_home)

# Check what color to use for team abbreviation based on pp or empty net
def get_score_color(power_play, empty_net):
    
    # TODO: make this better
    if power_play == "True" or power_play == True:
        power_play = True
    else:
        power_play = False

    if empty_net == "True" or empty_net == True:
        empty_net = True
    else:
        empty_net = False

    if power_play and empty_net:
        return FONT_COLOR_POWERPLAY_EMPTYNET
    elif empty_net:
        return FONT_COLOR_EMPTYNET
    elif power_play:
        return FONT_COLOR_POWERPLAY
    else:
        return FONT_COLOR_EVEN

def get_random_team():
    rand = random.number(0, len(TEAMS_LIST)-1)
    return TEAMS_LIST.keys()[rand]

def get_timezone(config):
    return json.decode(config.get("location", DEFAULT_LOCATION))['timezone']

            
# Schema 
def get_schema():
 
    team_schema_list = [ 
        schema.Option(display = t[1]['name'], value = str(t[0]))
        for t in sorted(TEAMS_LIST.items(), key=lambda item: item[1]['name'])
    ]
    team_schema_list.insert(0, schema.Option(display = "Shuffle All Teams", value = "0"))

    return schema.Schema(
        version = "1",
        fields = [
            schema.Dropdown(
                id = "teamid",
                name = "Team",
                desc = "The team you wish to follow.",
                icon = "user",
                options = team_schema_list,
                default = "0",
            ),
            schema.Location(
                id = "location",
                name = "Location",
                desc = "Location for which to display time.",
                icon = "place",
            ),
            schema.Toggle(
                id = "play",
                name = "Last Play",
                desc = "Toggle Last Play Info",
                icon = "hockey-puck",
                default = True,
            ),
            schema.Toggle(
                id = "lg",
                name = "Last Goal",
                desc = "Toggle Last Goal Info",
                icon = "hockey-puck",
                default = True,
            ),
            schema.Toggle(
                id = "sog",
                name = "SOG",
                desc = "Toggle Shots on Goal Stats",
                icon = "hockey-puck",
                default = True,
            ),
            schema.Toggle(
                id = "pen",
                name = "Penalties",
                desc = "Toggle Penalty Stats",
                icon = "hockey-puck",
                default = True,
            ),
            schema.Toggle(
                id = "pim",
                name = "PIM",
                desc = "Toggle Penalty Minutes Stats",
                icon = "hockey-puck",
                default = True,
            ),
            schema.Toggle(
                id = "ppg",
                name = "PPG",
                desc = "Toggle Power Play Goal Stats",
                icon = "hockey-puck",
                default = True,
            ),
            schema.Toggle(
                id = "fo",
                name = "Face Offs",
                desc = "Toggle Face Off Stats",
                icon = "hockey-puck",
                default = True,
            ),
            schema.Toggle(
                id = "hit",
                name = "Hit",
                desc = "Toggle Hits Stats",
                icon = "hockey-puck",
                default = True,
            ),
            schema.Toggle(
                id = "blk",
                name = "Blocks",
                desc = "Toggle Block Stats",
                icon = "hockey-puck",
                default = True,
            ),
            schema.Toggle(
                id = "take",
                name = "Takeaways",
                desc = "Toggle Takeaway Stats",
                icon = "hockey-puck",
                default = True,
            ),
            schema.Toggle(
                id = "give",
                name = "Giveaways",
                desc = "Toggle Giveaway Stats",
                icon = "hockey-puck",
                default = True,
            ),
        ],
    )