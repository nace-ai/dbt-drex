select {{ drex.drex_noul('body', criteria={'true': 'The customer wants money back', 'false': none}) }} as answer from tickets
