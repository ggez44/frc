require 'date'
require 'fileutils'
require 'uri'
require 'net/http'
require 'json'

require 'byebug'

API_KEY = "bUdXNYQIL7C5HYLSX966jAqfpmjbzocnaCoTdABBsOaHFAuyyid781XDRxwOrZD4"

def query(path, params = {})
  3.times do |i|
    uri = URI.parse("https://www.thebluealliance.com/api/v3/#{path}")
    uri.query = URI.encode_www_form(params)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl=true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER

    headers = {"X-TBA-Auth-Key" => API_KEY}
    request = Net::HTTP::Get.new(uri.request_uri, headers)
    response = http.request(request)
    return JSON.parse(response.body) if response.code == "200"
  rescue
  end
end

def get_event(event_key)
  cache_file_name = "cache/event_meta_cache_#{event_key}.json"
  if File.exists?(cache_file_name)
    event = File.open(cache_file_name) { |f| JSON.load(f) }
  else
    event = query("event/#{event_key}")
  end

  if is_event_cacheable(event)
    File.open(cache_file_name, "w") do |file|
      JSON.dump(event, file)
    end
  end

  return event
end

def get_event_matches(event_key)
  cache_file_name = "cache/event_matches_cache_#{event_key}.json"
  if File.exists?(cache_file_name)
    matches = File.open(cache_file_name) { |f| JSON.load(f) }
  else
    matches = query("event/#{event_key}/matches")

    event = get_event(event_key)
    if is_event_cacheable(event)
      File.open(cache_file_name, "w") do |file|
        JSON.dump(matches, file)
      end
    end
  end

  return matches
end

def is_event_cacheable(event)
  # only cache done events
  event_end_date = Date.parse(event["end_date"])
  days_diff = (Date.today - event_end_date).to_i

  return days_diff > 2
end

def get_stats(event_key, stat, use_prev_event_data)
  if !use_prev_event_data
    return run_event(event_key, stat)
  end

  # get data from prev event instead
  team_last_events = get_teams_last_event(event_key)

  team_results = {}

  team_last_events.each do |team_key, event_key|
    team_number = team_key.sub('frc', '')
    event_results = run_event(event_key, stat)
    team_results[team_number] = event_results[team_number]
  end

  return team_results
end


def run_event(event_key, stat)
  if !event_key
      raise "No event key"
  end

  event = get_event(event_key)
  matches = get_event_matches(event_key)

  team_scores = {}

  cache_file_name = "cache/event_stat_cache_#{event_key}_#{stat}.json"
  if File.exists?(cache_file_name)
    return File.open(cache_file_name) { |f| JSON.load(f) }
  else
    print(".")
    if stat == "auto_tower"
      team_scores = run_auto_tower_stats(matches)
    elsif stat == "endgame_tower"
      team_scores = run_endgame_tower_stats(matches, quiet: false)
    else
      50.times do
        team_scores = run_iteration(stat, team_scores, matches)
      end

      if stat == "eps_v_comp"
        team_scores.each do |team_key, score_hash|
          score_hash["score"] -= get_avg_eps_for_week(event["week"])
        end
      end
    end

    if is_event_cacheable(event)
      File.open(cache_file_name, "w") do |file|
        JSON.dump(team_scores, file)
      end
    end
  end

  return team_scores
end

def run_rp_pct()
  aggregator_by_team = {}
  events = query("events/2026")
  events.each do |event|
    next if [99,100].include?(event["event_type"])
    puts(event["key"])

    matches = get_event_matches(event["key"])
    result = run_rp_pct_event(matches)

    for team_key in result.keys()
      if aggregator_by_team.key?(team_key)
        aggregator_by_team[team_key]["match_count"] += result[team_key]["match_count"]
        aggregator_by_team[team_key]["rp"] += result[team_key]["rp"]
      else
        aggregator_by_team[team_key] = result[team_key]
      end
    end
  end

  pp aggregator_by_team.map { |t,d| [t, (d["rp"].to_f/(d["match_count"]*6)).round(4)] }.sort_by { |_,r| -r }
end

def run_rp_pct_event(matches)
  team_info = {}

  matches.each do |match|
    next if !match['actual_time']
    next if match['comp_level'] != 'qm'

    team1, team2, team3 = match["alliances"]["blue"]["team_keys"].map { |key| key.sub('frc', '') }
    team4, team5, team6 = match["alliances"]["red"]["team_keys"].map { |key| key.sub('frc', '') }

    [team1, team2, team3, team4, team5, team6].each do |team|
      if team_info.key?(team)
        team_info[team]["match_count"] += 1
      else
        team_info[team] = {"match_count"=>1, "rp"=>0} if !team_info.key?(team)
      end
    end

    [team1, team2, team3].each do |team|
      team_info[team]["rp"] += match["score_breakdown"]["blue"]["rp"]
    end
    [team4, team5, team6].each do |team|
      team_info[team]["rp"] += match["score_breakdown"]["red"]["rp"]
    end
  end

  return team_info
end

# Per-robot auto tower climb stats
def run_auto_tower_stats(matches)
  team_info = {}

  matches.each do |match|
    next if !match['actual_time']

    team1, team2, team3 = match["alliances"]["blue"]["team_keys"].map { |key| key.sub('frc', '') }
    team4, team5, team6 = match["alliances"]["red"]["team_keys"].map { |key| key.sub('frc', '') }

    [team1, team2, team3, team4, team5, team6].each do |team|
      team_info[team] = {"match_count"=>0, "climbed"=>[], "none"=>[]} if !team_info.key?(team)
    end

    bot_mappings = {
      ["blue", "1"] => team1,
      ["blue", "2"] => team2,
      ["blue", "3"] => team3,
      ["red", "1"] => team4,
      ["red", "2"] => team5,
      ["red", "3"] => team6,
    }

    bot_mappings.each do |bot_mapping, team_id|
      team_info[team_id]["match_count"] += 1
      status = match["score_breakdown"][bot_mapping[0]]["autoTowerRobot#{bot_mapping[1]}"]
      if status == "None"
        team_info[team_id]["none"] << match["key"]
      else
        team_info[team_id]["climbed"] << match["key"]
      end
    end
  end

  team_info.each do |team, data|
    team_info[team]["score"] = data["climbed"].length.to_f / data["match_count"]
  end

  idx = 0
  team_info.sort_by { |_, d| -d["score"] }.each do |team, data|
    pct = data["score"].round(2)
    puts "#{idx+=1}. #{team} - #{data['climbed'].length}/#{data['match_count']} (#{pct})"
  end

  return team_info
end

# Per-robot endgame tower climb stats (Level1 / Level2 / Level3)
def run_endgame_tower_stats(matches, quiet: false)
  team_info = {}

  matches.each do |match|
    next if !match['actual_time']

    team1, team2, team3 = match["alliances"]["blue"]["team_keys"].map { |key| key.sub('frc', '') }
    team4, team5, team6 = match["alliances"]["red"]["team_keys"].map { |key| key.sub('frc', '') }

    [team1, team2, team3, team4, team5, team6].each do |team|
      team_info[team] = {"match_count"=>0, "none_count"=>0, "level1_count"=>0, "level2_count"=>0, "level3_count"=>0, "no_climbs"=>[], "level1_matches"=>[], "level2_matches"=>[], "level3_matches"=>[]} if !team_info.key?(team)
    end

    bot_mappings = {
      ["blue", "1"] => team1,
      ["blue", "2"] => team2,
      ["blue", "3"] => team3,
      ["red", "1"] => team4,
      ["red", "2"] => team5,
      ["red", "3"] => team6,
    }

    bot_mappings.each do |bot_mapping, team_id|
      team_info[team_id]["match_count"] += 1
      status = match["score_breakdown"][bot_mapping[0]]["endGameTowerRobot#{bot_mapping[1]}"]
      case status
      when "None"
        team_info[team_id]["none_count"] += 1
        team_info[team_id]["no_climbs"] << match["key"]
      when "Level1"
        team_info[team_id]["level1_count"] += 1
        team_info[team_id]["level1_matches"] << match["key"]
      when "Level2"
        team_info[team_id]["level2_count"] += 1
        team_info[team_id]["level2_matches"] << match["key"]
      when "Level3"
        team_info[team_id]["level3_count"] += 1
        team_info[team_id]["level3_matches"] << match["key"]
      end
    end
  end

  team_info.each do |team, data|
    climbed = data["level1_count"] + data["level2_count"] + data["level3_count"]
    team_info[team]["score"] = climbed.to_f / data["match_count"]
  end

  sorted = team_info.sort_by { |_, d| -d["score"] }

  unless quiet
    puts "team \t matches \t none \t L1 \t L2 \t L3 \t climb%"
    sorted.each do |team, data|
      climbed = data["level1_count"] + data["level2_count"] + data["level3_count"]
      pct = data["score"].round(2)
      puts "#{team} \t #{data['match_count']} \t\t #{data['none_count']} \t #{data['level1_count']} \t #{data['level2_count']} \t #{data['level3_count']} \t #{pct}"
    end

    puts "\n--- Climb details by team ---"
    sorted.each do |team, data|
      next if data["level1_matches"].empty? && data["level2_matches"].empty? && data["level3_matches"].empty?
      puts "#{team}:"
      puts "  L1: #{tids(data['level1_matches']).join(', ')}" if data["level1_count"] > 0
      puts "  L2: #{tids(data['level2_matches']).join(', ')}" if data["level2_count"] > 0
      puts "  L3: #{tids(data['level3_matches']).join(', ')}" if data["level3_count"] > 0
    end
  end

  return team_info
end


def run_iteration(stat, team_scores, matches)
  iteration_team_scores = {}

  matches.each do |match|
    next if !match['actual_time']
    next if !match['score_breakdown']

    team1, team2, team3 = match["alliances"]["blue"]["team_keys"].map { |key| key.sub('frc', '') }
    team4, team5, team6 = match["alliances"]["red"]["team_keys"].map { |key| key.sub('frc', '') }

    blue_score = 0
    red_score = 0

    case stat
    when "eps", "eps_v_comp"
      blue_score = match["score_breakdown"]["blue"]["totalPoints"] - match["score_breakdown"]["blue"]["foulPoints"]
      red_score = match["score_breakdown"]["red"]["totalPoints"] - match["score_breakdown"]["red"]["foulPoints"]
    when "auto_fuel"
      blue_score = match["score_breakdown"]["blue"]["hubScore"]["autoCount"]
      red_score = match["score_breakdown"]["red"]["hubScore"]["autoCount"]
    when "teleop_fuel"
      blue_score = match["score_breakdown"]["blue"]["hubScore"]["teleopCount"]
      red_score = match["score_breakdown"]["red"]["hubScore"]["teleopCount"]
    when "total_fuel"
      blue_score = match["score_breakdown"]["blue"]["hubScore"]["totalCount"]
      red_score = match["score_breakdown"]["red"]["hubScore"]["totalCount"]
    when "total_tower_pts"
      blue_score = match["score_breakdown"]["blue"]["autoTowerPoints"] + match["score_breakdown"]["blue"]["endGameTowerPoints"]
      red_score = match["score_breakdown"]["red"]["autoTowerPoints"] + match["score_breakdown"]["red"]["endGameTowerPoints"]
    when "foul_points_committed"
      # look at opponent alliance foulPoints - TBA looks at own alliance which is meaningless
      blue_score = match["score_breakdown"]["red"]["foulPoints"]
      red_score = match["score_breakdown"]["blue"]["foulPoints"]
    end

    [team1, team2, team3, team4, team5, team6].each do |team|
      team_scores[team] ||= { "score" => 0 }
      iteration_team_scores[team] ||= { "score" => 0, "matches" => 0 }
    end

    alliance1_total = [team_scores[team1]["score"], team_scores[team2]["score"], team_scores[team3]["score"]].sum
    if alliance1_total == 0
      alliance1_percentages = [1.0/3, 1.0/3, 1.0/3]
    else
      alliance1_percentages = [team_scores[team1]["score"], team_scores[team2]["score"], team_scores[team3]["score"]].map { |score| score.to_f / alliance1_total }
    end

    alliance2_total = [team_scores[team4]["score"], team_scores[team5]["score"], team_scores[team6]["score"]].sum
    if alliance2_total == 0
      alliance2_percentages = [1.0/3, 1.0/3, 1.0/3]
    else
      alliance2_percentages = [team_scores[team4]["score"], team_scores[team5]["score"], team_scores[team6]["score"]].map { |score| score.to_f / alliance2_total }
    end

    iteration_team_scores[team1]["score"] += alliance1_percentages[0] * blue_score.to_i
    iteration_team_scores[team2]["score"] += alliance1_percentages[1] * blue_score.to_i
    iteration_team_scores[team3]["score"] += alliance1_percentages[2] * blue_score.to_i

    iteration_team_scores[team4]["score"] += alliance2_percentages[0] * red_score.to_i
    iteration_team_scores[team5]["score"] += alliance2_percentages[1] * red_score.to_i
    iteration_team_scores[team6]["score"] += alliance2_percentages[2] * red_score.to_i

    [team1, team2, team3, team4, team5, team6].each do |team|
      iteration_team_scores[team]["matches"] += 1
    end

  end

  iteration_team_scores.map do |team, score|
    team_scores[team]["score"] = score["score"] / score["matches"]
  end

  team_scores
end

def get_teams_last_event(event_key)
  # ignore championship events with very few matches
  unusable_events = ["2026txcmp", "2026micmp", "2026necmp", "2026oncmp"]

  cache_file_name = "cache/last_event_cache_#{event_key}.json"
  if File.exists?(cache_file_name)
    return File.open(cache_file_name) { |f| JSON.load(f) }
  end

  team_keys = get_team_keys(event_key)

  team_last_event_map = {}
  team_keys.each do |team_key|
    matches = query("team/#{team_key}/matches/2026")
    filtered_matches = matches.select { |match| match["actual_time"] }
    filtered_matches = filtered_matches.reject { |match| unusable_events.include?(match["event_key"]) }
    most_recent_match = filtered_matches.max_by { |match| match["actual_time"] }
    if most_recent_match
      team_last_event_map[team_key] = most_recent_match["event_key"]
    end
    print('.')
  end

  File.open(cache_file_name, "w") do |file|
    JSON.dump(team_last_event_map, file)
  end

  return team_last_event_map
end

def get_team_keys(event_key)
  teams = query("event/#{event_key}/teams")
  return teams.map{ |team| team["key"] }
end

# repopulate this cache each run
WEEKLY_AVG_EPS_CACHE = {}
def get_avg_eps_for_week(week_num)
  if WEEKLY_AVG_EPS_CACHE[week_num]
    return WEEKLY_AVG_EPS_CACHE[week_num]
  end

  event_averages = []
  events = query("events/2026")
  events.each do |event|
    next if event["week"].nil?
    next if event["week"].to_i != week_num.to_i

    event_results = run_event(event["key"], "eps")
    scores = event_results.values.map { |team| team["score"] }
    total_score = scores.sum
    average_score = total_score / scores.size
    event_averages.append(average_score)
  end

  average_eps = event_averages.sum / event_averages.count
  WEEKLY_AVG_EPS_CACHE[week_num] = average_eps
  return average_eps
end

def pprint(team_scores)
  idx = 0

  puts "\n==================="
  if team_scores.length == 0
    puts "No data yet"
  else
    team_scores.sort_by { |team, score| score["score"] }.reverse.each do |team, score|
      puts "#{idx+=1}. #{team}: #{score["score"].round(2)}"
    end
  end
end

def display_menu()
  puts "\n\n"
  puts "###################################################################\n#"
  if ARGV[1].nil?
    puts "#     Stats for #{ARGV[0]} teams using #{ARGV[0]} matches"
  else
    puts "#     Stats for #{ARGV[0]} teams using teams' latest event matches"
  end
  puts "#\n###################################################################"
  puts "\n"
  puts "1)  Estimated Points Share (sans fouls)"
  puts "2)  EPS vs Week Comp"
  puts "3)  Auto Fuel Count"
  puts "4)  Teleop Fuel Count"
  puts "5)  Total Fuel Count"
  puts "6)  Total Tower Points (auto + endgame)"
  puts "7)  Foul Points Committed"
  puts "8)  Auto Tower Climb Stats (per robot)"
  puts "9)  Endgame Tower Climb Stats (per robot)"
  puts "10) RP Avg"
  puts "11) Forecast Match Results (unplayed matches)"
  puts "12) Forecast Match Results (current event + latest event EPS averaged)"
  puts ""
  puts "[w]eekly average scores"
  puts "[c]lear cache"
  puts "[q]uit"
  puts ""
  print "Enter choice: "
end

def get_team_max_climb(team, endgame_stats)
  return 0 unless endgame_stats && endgame_stats[team]
  data = endgame_stats[team]
  return 3 if data["level3_count"] > 0
  return 2 if data["level2_count"] > 0
  return 1 if data["level1_count"] > 0
  0
end

def can_alliance_climb_rp?(teams, endgame_stats)
  # Predict climb RP if at least 2 of 3 robots have ever demonstrated a climb
  teams.count { |team| get_team_max_climb(team, endgame_stats) > 0 } >= 2
end

def get_current_rp_totals(event_key)
  rankings_data = query("event/#{event_key}/rankings")
  return {} unless rankings_data && rankings_data["rankings"]

  rp_totals = {}
  rankings_data["rankings"].each do |entry|
    team = entry["team_key"].sub('frc', '')
    avg_rp = entry["sort_orders"][0].to_f
    matches = entry["matches_played"].to_i
    rp_totals[team] = { "current_rp" => (avg_rp * matches).round, "matches_played" => matches }
  end
  rp_totals
end

def forecast_match_rp(match, team_scores, endgame_stats)
  t1, t2, t3 = match["alliances"]["blue"]["team_keys"].map { |k| k.sub('frc', '') }
  t4, t5, t6 = match["alliances"]["red"]["team_keys"].map { |k| k.sub('frc', '') }

  blue_score = [t1, t2, t3].sum { |t| (team_scores.dig(t, "score") || 0) }.round
  red_score  = [t4, t5, t6].sum { |t| (team_scores.dig(t, "score") || 0) }.round

  if blue_score > red_score
    blue_rp = 3; red_rp = 0
  elsif red_score > blue_score
    blue_rp = 0; red_rp = 3
  else
    blue_rp = 1; red_rp = 1
  end

  blue_rp += 1 if blue_score >= 360
  blue_rp += 1 if blue_score >= 500
  red_rp  += 1 if red_score  >= 360
  red_rp  += 1 if red_score  >= 500

  blue_climb = can_alliance_climb_rp?([t1, t2, t3], endgame_stats)
  red_climb  = can_alliance_climb_rp?([t4, t5, t6], endgame_stats)
  blue_rp += 1 if blue_climb
  red_rp  += 1 if red_climb

  {
    t1 => blue_rp, t2 => blue_rp, t3 => blue_rp,
    t4 => red_rp,  t5 => red_rp,  t6 => red_rp,
    :blue_score => blue_score, :red_score => red_score,
    :blue_rp => blue_rp, :red_rp => red_rp,
    :blue_climb => blue_climb, :red_climb => red_climb,
    :t1 => t1, :t2 => t2, :t3 => t3,
    :t4 => t4, :t5 => t5, :t6 => t6,
  }
end

def run_forecast(event_key, use_prev_event_data: false, use_combined_data: false)
  print "Computing EPS scores"
  if use_combined_data
    current_scores = run_event(event_key, "eps")
    prev_scores    = get_stats(event_key, "eps", true)
    all_teams = (current_scores.keys + prev_scores.keys).uniq
    team_scores = {}
    all_teams.each do |team|
      cur  = current_scores.dig(team, "score")
      prev = prev_scores.dig(team, "score")
      avg  = if cur && prev then (cur + prev) / 2.0
             elsif cur      then cur
             else                prev
             end
      team_scores[team] = { "score" => avg }
    end
  else
    team_scores = get_stats(event_key, "eps", use_prev_event_data)
  end
  puts ""

  matches = get_event_matches(event_key)
  endgame_stats = run_endgame_tower_stats(matches, quiet: true)

  unplayed = matches.select { |m| m['comp_level'] == 'qm' && !m['actual_time'] }

  if unplayed.empty?
    puts "\nNo unplayed qualification matches found."
    return
  end

  current_rp = get_current_rp_totals(event_key)
  forecasted_rp = Hash.new(0)

  puts "\n#{"Match".ljust(8)} #{"Blue".rjust(5)} #{"Red".rjust(5)}  #{"BlRP".rjust(4)} #{"RdRP".rjust(4)}  Blue Alliance vs Red Alliance"
  puts "-" * 80

  unplayed.sort_by { |m| m['match_number'] }.each do |match|
    r = forecast_match_rp(match, team_scores, endgame_stats)

    blue_flag = r[:blue_climb] ? "*" : " "
    red_flag  = r[:red_climb]  ? "*" : " "

    puts "qm#{match['match_number'].to_s.ljust(5)} #{r[:blue_score].to_s.rjust(5)} #{r[:red_score].to_s.rjust(5)}  #{(r[:blue_rp].to_s + blue_flag).rjust(4)} #{(r[:red_rp].to_s + red_flag).rjust(4)}  (#{r[:t1]} #{r[:t2]} #{r[:t3]}) vs (#{r[:t4]} #{r[:t5]} #{r[:t6]})"

    [r[:t1], r[:t2], r[:t3]].each { |t| forecasted_rp[t] += r[:blue_rp] }
    [r[:t4], r[:t5], r[:t6]].each { |t| forecasted_rp[t] += r[:red_rp] }
  end

  puts "\n* = climb RP predicted (2-of-3 robots demonstrated climb)"
  puts "RP: 3 win, 1 each tie, +1 >=360 pts, +1 >=500 pts, +1 climb"

  # Build final standings: current RP + forecasted RP
  all_teams = (current_rp.keys + forecasted_rp.keys).uniq
  final_standings = all_teams.map do |team|
    cur  = current_rp.dig(team, "current_rp") || 0
    fore = forecasted_rp[team] || 0
    played = current_rp.dig(team, "matches_played") || 0
    { "team" => team, "current" => cur, "forecasted" => fore, "total" => cur + fore, "played" => played }
  end.sort_by { |t| -t["total"] }

  puts "\n=== Projected Final Standings ==="
  puts "#{"Rank".ljust(5)} #{"Team".ljust(9)} #{"Curr RP".rjust(7)} #{"+ Fore".rjust(7)} #{"= Total".rjust(7)}"
  puts "-" * 42
  final_standings.each_with_index do |t, i|
    climbed = get_team_max_climb(t['team'], endgame_stats) > 0
    team_label = (t['team'] + (climbed ? "*" : "")).ljust(9)
    puts "#{(i+1).to_s.ljust(5)} #{team_label} #{t['current'].to_s.rjust(7)} #{t['forecasted'].to_s.rjust(7)} #{t['total'].to_s.rjust(7)}"
  end
  puts "\n* = demonstrated climb this event"
end

def run_match_forecast(event_key, team_scores)
  matches = get_event_matches(event_key)
  matches.each do |match|
    team1, team2, team3 = match["alliances"]["blue"]["team_keys"].map { |key| key.sub('frc', '') }
    team4, team5, team6 = match["alliances"]["red"]["team_keys"].map { |key| key.sub('frc', '') }

    blue_total = (team_scores[team1]["score"] + team_scores[team2]["score"] + team_scores[team3]["score"]).round()
    red_total = (team_scores[team4]["score"] + team_scores[team5]["score"] + team_scores[team6]["score"]).round()

    puts "#{match["key"]}:   \t #{red_total} \t- #{blue_total}     \t(#{team4} #{team5} #{team6}) - (#{team1} #{team2} #{team3})"
  end
end

def handle_choice(choice)
  # if there is a second command line arg of any kind.. we use prev event
  use_prev_event_data = !ARGV[1].nil?

  choice_map = {
    "1" => "eps",
    "2" => "eps_v_comp",
    "3" => "auto_fuel",
    "4" => "teleop_fuel",
    "5" => "total_fuel",
    "6" => "total_tower_pts",
    "7" => "foul_points_committed",
  }

  event_key = ARGV[0]

  case choice
  when "12"
    run_forecast(event_key, use_combined_data: true)
  when "11"
    run_forecast(event_key)
  when "10"
    run_rp_pct()
  when *choice_map.keys
    pprint(get_stats(event_key, choice_map[choice], use_prev_event_data))
  when "8"
    get_stats(event_key, "auto_tower", use_prev_event_data)
  when "9"
    get_stats(event_key, "endgame_tower", use_prev_event_data)
  when "c"
    FileUtils.rm_rf("cache")
    FileUtils.mkdir_p("cache")
  when "w"
    puts("Week 1: #{get_avg_eps_for_week(0)}")
    puts("Week 2: #{get_avg_eps_for_week(1)}")
    puts("Week 3: #{get_avg_eps_for_week(2)}")
    puts("Week 4: #{get_avg_eps_for_week(3)}")
    puts("Week 5: #{get_avg_eps_for_week(4)}")
    puts("Week 6: #{get_avg_eps_for_week(5)}")
  end
end

def run_menu()
  FileUtils.mkdir_p("cache")
  choice = ''
  until choice == 'q'
    display_menu()
    choice = STDIN.gets.chomp
    handle_choice(choice)
  end
end

def tids(input)
  if input.is_a?(Array)
    res = input.map { |str| str.split('_', 2)[1] }
    res.sort_by { |res| res[/\d+/].to_i }
  elsif input.is_a?(String)
    input.split('_', 2)[1]
  end
end

run_menu()
