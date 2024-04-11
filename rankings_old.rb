require 'byebug'

results = "
Quals 1
3256	6814	972	6059	4255	3045	84	39
Quals 2
841	6619	751	5985	9470	7729	112	20
Quals 3
6418	5419	4990	9519	7840	5507	88	44
Quals 4
7401	649	2288	6238	766	7667	88	18
Quals 5
9545	1678	7245	1160	5940	9111	89	72
Quals 6
4698	4186	1700	4973	3482	254	54	66
Quals 7
2854	581	114	6884	2637	2204	103	23
Quals 8
4669	9202	9634	9781	9038	9609	10	42
Quals 9
1458	5274	4904	7137	8793	8159	73	41
Quals 10
7419	8852	5430	8045	199	4159	35	29
Quals 11
4255	751	6418	2288	5419	6619	42	102
Quals 12
9470	9519	6814	766	1160	5985	28	69
Quals 13
6238	972	7401	254	1700	5940	48	151
Quals 14
7667	7840	1678	3482	841	114	78	86
Quals 15
7729	6884	9038	4186	2204	4973	46	20
Quals 16
9202	6059	9111	5274	4698	649	21	81
Quals 17
8159	2637	8852	7419	9545	9634	70	50
Quals 18
4904	8793	199	4669	4990	3045	17	42
Quals 19
7137	5430	8045	7245	9609	581	20	102
Quals 20
5507	4159	1458	3256	2854	9781	44	46
Quals 21
766	6619	3482	5419	114	254	70	112
Quals 22
7840	7401	5985	6814	9038	4186	36	32
Quals 23
2204	9519	9202	4255	9111	972	34	46
Quals 24
5274	4973	9470	2288	7667	7419	39	71
Quals 25
3045	4698	1678	9545	4669	8852	110	50
Quals 26
841	1160	7137	199	6238	6884	71	48
Quals 27
4159	2854	4990	7245	9634	8159	87	52
Quals 28
649	7729	1458	8045	581	5507	48	62
Quals 29
5940	6418	9609	2637	3256	8793	111	37
Quals 30
1700	9781	6059	5430	751	4904	22	20
Quals 31
766	7840	4973	9202	6619	5274	40	67
Quals 32
2204	2288	4669	5985	8852	6814	59	61
Quals 33
9111	3045	5419	6884	7401	7419	83	30
Quals 34
7667	7137	4698	9634	1160	4990	68	27
Quals 35
7729	4255	7245	6238	1458	9038	29	100
Quals 36
649	254	2854	9519	9545	3256	127	48
Quals 37
199	3482	581	9781	751	5940	61	68
Quals 38
8045	1678	9470	6418	4904	1700	82	52
Quals 39
5507	8159	114	8793	5430	6059	115	28
Quals 40
9609	4186	2637	4159	972	841	41	78
Quals 41
2204	5419	9634	5274	3045	1160	61	60
Quals 42
7245	5985	7137	7840	7419	9202	56	41
Quals 43
6619	4973	4698	7401	1458	2854	87	32
Quals 44
9038	3256	2288	581	9111	9519	83	71
Quals 45
254	4904	4255	649	7667	8852	114	76
Quals 46
5430	9470	6238	3482	8793	9545	48	50
Quals 47
4186	5507	751	114	8045	2637	27	66
Quals 48
6059	4669	6418	6884	5940	4159	51	76
Quals 49
8159	766	972	199	9781	1678	73	80
Quals 50
9609	7729	841	1700	4990	6814	69	44
Quals 51
3256	2204	7245	7137	7401	4973	56	14
Quals 52
8852	4904	9519	581	7419	5274	27	103
Quals 53
9111	5985	6238	5419	2854	5430	18	71
Quals 54
9038	649	3045	114	9470	4698	54	73
Quals 55
751	254	1160	8793	4159	7840	96	37
Quals 56
4669	5940	4186	5507	4255	766	89	70
Quals 57
4990	9202	6884	1678	6814	3482	30	100
Quals 58
841	199	6059	6619	9634	1458	46	54
Quals 59
972	9609	9545	7729	7667	6418	68	30
Quals 60
8159	8045	9781	1700	2288	2637	26	45
Quals 61
8852	114	3256	9470	7245	5419	103	58
Quals 62
751	6238	5274	4698	9038	5430	47	59
Quals 63
5940	3045	766	2854	7137	7840	116	54
Quals 64
4159	581	4255	4973	4990	9111	65	30
Quals 65
1678	254	841	7419	6059	2204	152	24
Quals 66
9545	6814	6619	972	5507	4904	71	80
Quals 67
9634	1700	8045	5985	6884	8793	43	45
Quals 68
2637	9519	7667	1458	4669	199	36	55
Quals 69
6418	3482	7401	9609	8159	649	40	88
Quals 70
9202	9781	2288	1160	7729	4186	52	44
Quals 71
4990	8852	5940	114	9111	751	102	62
Quals 72
6059	6238	7840	9470	2204	581	41	64
Quals 73
4698	5507	3256	4904	841	766	85	77
Quals 74
9038	4159	1700	5419	9545	7137	56	84
Quals 75
1678	9634	8793	9519	4973	4255	81	43
Quals 76
972	5274	3482	2854	8045	4669	74	36
Quals 77
1458	7419	1160	4186	6418	649	30	64
Quals 78
6814	6884	9781	7667	7245	6619	29	77
Quals 79
2288	5985	8159	3045	9609	254	59	113
Quals 80
2637	5430	199	7401	9202	7729	55	21
Quals 81
5940	114	2204	4904	4698	4159	127	76
Quals 82
9634	7137	9470	9111	1678	5507	37	102
Quals 83
8793	766	2854	8852	6059	9038	54	75
Quals 84
4973	972	4669	751	649	5419	78	70
Quals 85
6619	4186	7419	4990	3256	6238	81	57
Quals 86
581	1700	5985	1160	8159	7667	80	54
Quals 87
7840	1458	6884	5430	2288	9609	42	89
Quals 88
9781	5274	9545	4255	841	7401	49	73
Quals 89
3482	2637	7729	3045	7245	9519	43	59
Quals 90
254	6418	8045	6814	199	9202	99	40
"

def run_iteration(team_scores, results_clean)
  iteration_team_scores = {}

  results_clean.each do |line|
    #puts "==================="
    #puts line
    #puts "==================="
    line = line.split("\t")
    team1, team2, team3, team4, team5, team6, score1, score2 = line

    [team1, team2, team3, team4, team5, team6].each do |team|
      team_scores[team] ||= { score: 0 }
      iteration_team_scores[team] ||= { score: 0, matches: 0 }
    end

    alliance1_total = [team_scores[team1][:score], team_scores[team2][:score], team_scores[team3][:score]].sum
    if alliance1_total == 0
      alliance1_percentages = [1.0/3, 1.0/3, 1.0/3]
    else
      alliance1_percentages = [team_scores[team1][:score], team_scores[team2][:score], team_scores[team3][:score]].map { |score| score.to_f / alliance1_total }
    end

    alliance2_total = [team_scores[team4][:score], team_scores[team5][:score], team_scores[team6][:score]].sum
    if alliance2_total == 0
      alliance2_percentages = [1.0/3, 1.0/3, 1.0/3]
    else
      alliance2_percentages = [team_scores[team4][:score], team_scores[team5][:score], team_scores[team6][:score]].map { |score| score.to_f / alliance2_total }
    end

    iteration_team_scores[team1][:score] += alliance1_percentages[0] * score1.to_i
    iteration_team_scores[team2][:score] += alliance1_percentages[1] * score1.to_i
    iteration_team_scores[team3][:score] += alliance1_percentages[2] * score1.to_i

    iteration_team_scores[team4][:score] += alliance2_percentages[0] * score2.to_i
    iteration_team_scores[team5][:score] += alliance2_percentages[1] * score2.to_i
    iteration_team_scores[team6][:score] += alliance2_percentages[2] * score2.to_i

    iteration_team_scores[team1][:matches] += 1
    iteration_team_scores[team2][:matches] += 1
    iteration_team_scores[team3][:matches] += 1
    iteration_team_scores[team4][:matches] += 1
    iteration_team_scores[team5][:matches] += 1
    iteration_team_scores[team6][:matches] += 1
  end

  iteration_team_scores.map do |team, score|
    team_scores[team][:score] = score[:score] / score[:matches]
  end

  team_scores
end

def pprint(team_scores)
  idx = 0
  puts "==================="
  team_scores.sort_by { |team, score| score[:score] }.reverse.each do |team, score|
    puts "#{idx+=1}. #{team} - #{score[:score].round(2)}"
  end
end


results = results.split("\n")

results_clean = []
results.each do |line|
  next if line.start_with?("Quals")
  next if line.empty?

  results_clean << line
end

team_scores = {}

50.times do
  team_scores = run_iteration(team_scores, results_clean)
  #pprint(team_scores)
end
pprint(team_scores)

