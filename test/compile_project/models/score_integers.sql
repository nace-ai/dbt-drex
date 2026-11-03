select {{ drex.drex_score('body', 'Rate the review', [1, 2, 3, 4, 5]) }} as answer from tickets
