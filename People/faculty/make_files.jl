using CSV, DataFrames
using Mustache
# NM,NOTE,OFFICE,PHONE,RANK,URL,EMAIL,IMG,INTERESTS,BIO
tpl = mt"""
---
title: {{{:NM}}}
image: {{#:IMG}}{{{:IMG}}}{{/:IMG}}{{^:IMG}}./default.png{{/:IMG}}
image-alt: {{{:NM}}}
description: {{:RANK}}
about:
  template: solana
  image-width: 25%
---


{{:INTERESTS}}

## Contacts

**Office**    | {{#:OFFICE}}{{{:OFFICE}}}{{/:OFFICE}}     <br/>
**Telephone** | {{{:PHONE}}}                              <br/>
**Email**     | `{{{:EMAIL}}}`                            <br/>
**url**       | {{#:URL}}[{{{:URL}}}]({{{:URL}}}){{/:URL}}  <br/>


"""

d = CSV.read("faculty.csv", DataFrame)
for r ∈ eachrow(d)
    first,last = split(r.NM, " ")
    fname = "$last-$first.qmd"
    fname = replace(fname, "'" => "")

    open(fname,"w") do io
        Mustache.render(io, tpl; r...)
    end
end
