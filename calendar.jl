#Script to generate calendar page; run once per XXX

```{julia}
using CSV
using Mustache
using Markdown
using DataFrames
using Dates

calendar_tpl = mt"""
<h3>Upcoming calendar events</h3>
{{^:CALENDAR}}No upcoming events listed{{/:CALENDAR}}
{{@:CALENDAR}}
<table class="table table-striped">
  <thead>
    <tr>
      <th scope="col">Date&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</th>
      <th scope="col">Event</th>
    </tr>
  </thead>
<tbody>
{{/:CALENDAR}}{{#:CALENDAR}}
    <tr>
    <th scope="row">{{{:DATE}}}</th>
      <td>{{{:EVENT}}}</td>
    </tr>
{{/:CALENDAR}}{{@:CALENDAR}}
  </tbody>
</table>
{{/:CALENDAR}}
"""
function make_calendar()
    d = CSV.read("calendar.csv", DataFrame)
    d = d[completecases(d), :]
    d.DATE = Date.(d[:, 1], d[:, 2], d[:, 3])
    d.EVENT = d[:, 4]
    d = filter(:DATE => x -> x > today(), d)
    d = d[sortperm(d.DATE), :]

    # we do two things: make a 5-entry page; make a calendar
    no_calendar_items = 5
    d[1:min(no_calendar_items, size(d, 1)), :], d
end
calendar = make_calendar()[2]
CALENDAR = Mustache.render(calendar_tpl, CALENDAR=calendar)
Markdown.parse(CALENDAR)
