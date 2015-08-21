Lockr      = require 'lockr'
tl         = require 'talio'

{div, main, span, pre, nav, section, header, aside,
 small, i, p, b, a, button, code,
 h1, h2, h3, h4, strong,
 form, legend, label, input, textarea, select, label, option,
 table, thead, tbody, tfoot, tr, th, td
 dl, dt, dd,
 ul, li} = require 'virtual-elements'

module.exports = (state, channels) ->
  (form
    'ev-submit': tl.sendSubmit channels.sendTextAsFile
  ,
    (header {},
      (input
        title: "rename #{state.attachment.name}"
        name: 'attachment.name'
        value: state.attachment.name
        'ev-input': tl.sendChange channels.change
      )
      (button
        type: 'submit'
      , 'Save')
    )
    (main {},
      (aside {},
        (div {}, "you are connected as ", (h1 {}, state.user.username)) if state.user.id
        (div {},
          (h1 {}, 'Attachments ')
          (small {}, 'choose an attachment') if not state.attachment.id and state.card.attachments.length
          (button
            'ev-click': tl.sendClick channels.newAttachment, {kind: 'js'}, {preventDefault: true}
          , 'new javascript')
          (button
            'ev-click': tl.sendClick channels.newAttachment, {kind: 'css'}, {preventDefault: true}
          , 'new CSS')
          (button
            'ev-click': tl.sendClick channels.newAttachment, {kind: 'txt'}, {preventDefault: true}
          , 'new text')
          (ul {}, state.card.attachments.map (att) ->
            (li {},
              (a
                title: "edit or rename #{att.name}"
                href: "#/b/#{state.board.id}/c/#{state.card.id}/a/#{att.name}"
                className: if att.id == state.attachment.id then 'selected' else ''
              ,
                att.name
                (button
                  title: "delete #{att.name}"
                  'ev-click': tl.sendClick channels.deleteAttachment,
                              {card: state.card.id, attachment: att.id},
                              {preventDefault: true}
                , '×')
              )
            )
          ) if state.card.attachments.length
        ) if state.card.id
        (div {},
          (h1 {}, 'Cards ')
          (small {}, 'choose a card') if not state.card.id
          (ul {}, state.board.cards.map (c) ->
            (li {}, (a
              href: "#/b/#{state.board.id}/c/#{c.id}"
              className: if c.id == state.card.id then 'selected' else ''
            , c.name))
          )
        ) if state.board.cards.length
        (div {},
          (h1 {}, 'Boards ')
          (small {}, 'choose a board') if not state.board.id
          (ul {}, state.user.boards.map (b) ->
            (li {}, (a
              href: "#/b/#{b.id}"
              className: if b.id == state.board.id then 'selected' else ''
            , b.name))
          )
        ) if state.user.boards.length
      )
      (textarea
        title: "edit #{state.attachment.name}"
        name: 'attachment.content'
        value: state.attachment.content or Lockr.get "text:#{state.card.id}/#{state.attachment.name}"
        'ev-input': tl.sendChange channels.change
      )
    )
  )
