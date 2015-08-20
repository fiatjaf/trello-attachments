tl         = require 'talio'

{div, main, span, pre, nav, section, header, aside, article,
 small, i, p, b, a, button, code,
 h1, h2, h3, h4, strong,
 form, legend, label, input, textarea, select, label, option,
 table, thead, tbody, tfoot, tr, th, td
 dl, dt, dd,
 ul, li} = require 'virtual-elements'

module.exports = (state, channels) ->
  (div id: 'app',
    if state.user.id then (require './vrender-edit')(state, channels) else (button
      'ev-click': tl.sendClick channels.login, {}, {preventDefault: true}
    , "connect with Trello")
  )
