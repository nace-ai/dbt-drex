{#-
  The tickets, as edited between runs of the incremental test: var('drex_test_edit') edits ticket 2 and adds ticket 5,
  and var('drex_test_second_edit') edits ticket 3 too
-#}
select
    id,
    subject,
    {% if var("drex_test_edit", false) -%}
    case
        when id = 2 then {{ dbt.concat(["nullif(body, '')", "' Also, the app logs me out.'"]) }}
        {% if var("drex_test_second_edit", false) -%}
        when id = 3 then {{ dbt.concat(["nullif(body, '')", "' It started after the update.'"]) }}
        {% endif -%}
        else nullif(body, '')
    end as body
    {%- else -%}
    nullif(body, '') as body
    {%- endif %}
from {{ ref("tickets") }}
where added_in_edit = 0 {% if var("drex_test_edit", false) %}or added_in_edit = 1{% endif %}
