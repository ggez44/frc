require 'byebug'

results = "
Quals 1
6814	8016	6962	8793	9006	9111	34	8
Quals 2
7245	6418	1458	9143	5700	7130	24	11
Quals 3
5507	4973	4698	4669	8840	8033	44	49
Quals 4
4186	1671	1700	971	9114	2489	27	51
Quals 5
7426	4765	5940	846	9038	6822	120	24
Quals 6
114	9584	2854	5924	852	6662	46	29
Quals 7
2643	841	2551	8852	4904	840	30	63
Quals 8
8016	9111	649	4669	1458	6962	37	31
Quals 9
9006	4186	9143	8793	4698	5700	22	37
Quals 10
971	7130	5507	2489	846	6814	54	53
Quals 11
852	114	8033	1700	7245	5940	95	79
Quals 12
8840	9584	7426	2854	841	1671	45	56
Quals 13
4904	5924	2643	4765	4973	840	29	49
Quals 14
9114	6662	6822	649	6418	8852	61	54
Quals 15
9038	4669	9006	1458	2551	971	23	63
Quals 16
5700	5507	8016	4186	5940	852	64	53
Quals 17
6814	114	7130	4698	1671	6962	63	51
Quals 18
8793	2489	5924	8033	7245	9584	41	45
Quals 19
846	9111	841	840	649	9114	39	64
Quals 20
2551	4904	9143	2854	2643	6822	30	37
Quals 21
9038	8852	6662	1700	8840	4973	39	36
Quals 22
4765	6418	4669	114	7426	4186	60	84
Quals 23
6962	5507	5940	971	5924	7245	83	35
Quals 24
2489	9584	1458	846	840	4698	58	55
Quals 25
6822	6814	2551	841	8033	8016	21	83
Quals 26
9143	4973	9038	9111	2854	8852	21	39
Quals 27
1671	5700	649	6418	8840	852	52	30
Quals 28
8793	1700	9114	7130	4765	4904	38	20
Quals 29
6662	9006	2489	2643	7426	4669	40	48
Quals 30
2551	4698	4186	5924	846	6962	50	46
Quals 31
6822	8852	9584	9111	6814	5507	18	16
Quals 32
9038	971	852	841	114	6418	36	89
Quals 33
7245	840	8840	9114	1458	4904	41	49
Quals 34
5700	6662	2643	7130	8016	1700	34	35
Quals 35
8033	5940	4973	1671	8793	7426	83	57
Quals 36
9143	2854	4765	5507	649	9006	20	52
Quals 37
852	2489	8852	6418	6962	6822	55	54
Quals 38
7245	9114	6814	2551	4669	114	24	68
Quals 39
9111	4698	2643	5700	4186	9038	36	34
Quals 40
7426	1700	846	4973	8793	4904	53	14
Quals 41
971	8033	4765	8840	6662	1458	63	51
Quals 42
2854	9006	5940	840	7130	9584	81	42
Quals 43
8016	1671	5924	841	649	9143	60	64
Quals 44
4186	2643	6814	6962	9038	7245	22	55
Quals 45
5507	846	8793	852	5700	2551	23	40
Quals 46
4904	9111	2489	6662	4765	114	37	77
Quals 47
840	971	6418	4698	8033	2854	60	84
Quals 48
649	5924	7130	8852	7426	8016	48	56
Quals 49
4669	9143	1700	8840	5940	841	24	78
Quals 50
1458	6822	4973	9584	9114	9006	35	45
Quals 51
1671	6814	9038	4186	4904	5507	34	41
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

