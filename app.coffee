Promise    = require 'lie'
Trello     = require 'trello-browser'
Router     = require 'routerjs'
Lockr      = require 'lockr'
tl         = require 'talio'
superagent = Trello.superagent

trello = new Trello 'ac61d8974aa86dd25f9597fa651a2ed8'

router = new Router()

State = tl.StateFactory
  user:
    id: ''
    boards: []
  board:
    id: ''
    cards: []
  card:
    id: ''
    attachments: []
  attachment:
    name: ''
    id: ''
    url: ''
    mimeType: ''
    content: ''

handlers =
  change: (State, data) ->
    key = Object.keys(data)[0]
    State.change key, data[key]
  onLogged: (State) ->
    Promise.resolve().then(->
      trello.get "/1/tokens/#{trello.token}/member", {fields: 'username,id'}
    ).then((user) ->
      State.silentlyUpdate 'user', user
      document.body.appendChild document.getElementById('app')
      remove = document.querySelector('body > article')
      document.body.removeChild remove
    ).catch(->
      Lockr.set 'token', null
    ).catch(console.log.bind console)
  login: (State) ->
    Promise.resolve().then(->
      if not State.get 'user.id'
        trello.auth
          name: 'Trello Attachment Editor'
          scope:
            read: true
            write: true
          expiration: '1hour'
    ).then(=>
      now = new Date
      Lockr.set 'token', trello.token
      Lockr.set 'token-expires', now.setMinutes now.getMinutes() + 59

      @onLogged State
    ).then(->
      router.redirect "#/user/#{State.get 'user.id'}"
    ).catch(console.log.bind console)
  listBoards: (State) ->
    Promise.resolve().then(=>
      if not State.get('user.id')
        router.redirect '#/login'
    ).then(->
      trello.get "/1/members/#{State.get 'user.id'}/boards", {
        filter: 'open'
        fields: 'id,name'
      }
    ).then((boards) ->
      State.change 'user.boards', boards
    ).catch(console.log.bind console)
  listCards: (State) ->
    Promise.resolve().then(=>
      if not State.get('user.boards').length
        @listBoards State
    ).then(->
      trello.get "/1/boards/#{State.get 'board.id'}/cards", {
        filter: 'open'
        fields: 'id,name'
      }
    ).then((cards) ->
      State.change 'board.cards', cards
    ).catch(console.log.bind console)
  listAttachments: (State) ->
    Promise.resolve().then(=>
      if not State.get('board.cards').length
        @listCards State
    ).then(->
      trello.get "/1/cards/#{State.get 'card.id'}/attachments", {
        fields: 'id,name,url,mimeType'
      }
    ).then((attachments) ->
      State.change 'card.attachments', attachments
    ).catch(console.log.bind console)
  fetchAttachment: (State) ->
    Promise.resolve().then(=>
      if not State.get('card.attachments').length
        @listAttachments State
    ).then(->
      for attachment in State.get 'card.attachments'
        if attachment.name == State.get 'attachment.name'
          State.silentlyUpdate 'attachment', attachment
          return Promise.resolve().then(->
            superagent.get('//cors-anywhere.herokuapp.com/' + attachment.url)
          ).then((res) ->
            State.change 'attachment.content', res.text
          )
      throw new Error 'no attachment found with that name.'
    ).catch(=>
      @newAttachment State, State.get 'attachment.name'
    ).catch(console.log.bind console)
  newAttachment: (State, name) ->
    State.change
      attachment:
        id: null
        name: name
        content: switch name.split('.').slice(-1)[0]
          when 'js' then 'document.addEventListener("DOMContentLoaded", function () {\n\n})'
          when 'css' then 'body > main article {\n\n}'
          else '# new attachment'
    router.redirect "#/b/#{State.get 'board.id'}/c/#{State.get 'card.id'}/a/#{name}"
  sendTextAsFile: (State, data) ->
    Promise.resolve().then(->
      trello.post "/1/cards/#{State.get 'card.id'}/attachments", {
        mimeType: ''
        name: State.get 'attachment.name'
        file: data['attachment.content']
      }
    ).then((res) ->
      if State.get 'attachment.id'
        trello
          .delete("/1/cards/#{State.get 'card.id'}/attachments/#{State.get 'attachment.id'}")
          .catch(console.log.bind console)
      State.change 'attachment.id', res.id
    ).then(handlers.listAttachments.bind handlers, State)
     .catch(console.log.bind console)

Promise.resolve('starting...').then(->
  console.log 'referrer:', document.referrer
  if -1 != document.referrer.indexOf 'https://trello.com/'
    cardReferred = document.referrer.split('/')[4]
    trello.get "/1/cards/#{cardReferred}", {fields: 'id,idBoard'}
).then((card) ->
  if card
    location.hash = "#/b/#{card.idBoard}/c/#{card.id}"

  if (new Date) < Lockr.get 'token-expires'
    trello.token = Lockr.get 'token'
    handlers.onLogged(State)
).then(->
  router
    .addRoute '#/login', (req) ->
      console.log 'logging in'
    .addRoute '#/user/:user', (req) ->
      if req.params.user != State.get 'user.id'
        State.silentlyUpdate 'user', {boards: []}
        router.redirect '#/login'
      else
        State.silentlyUpdate 'user.id', req.params.user
        handlers.listBoards State
    .addRoute '#/b/:board', (req) ->
      State.silentlyUpdate 'board.id', req.params.board
      State.silentlyUpdate 'card', {attachments: []}
      State.silentlyUpdate 'attachment', {}
      handlers.listCards State
    .addRoute '#/b/:board/c/:card', (req) ->
      State.silentlyUpdate 'board.id', req.params.card
      State.silentlyUpdate 'card.id', req.params.card
      State.silentlyUpdate 'attachment', {}
      handlers.listAttachments State
    .addRoute '#/b/:board/c/:card/a/:attachmentName', (req) ->
      State.silentlyUpdate 'board.id', req.params.card
      State.silentlyUpdate 'card.id', req.params.card
      State.silentlyUpdate 'attachment.name', req.params.attachmentName
      handlers.fetchAttachment State
    .errors 404, (err, href) ->
      console.log 'no route', err, href
      router.redirect '#/login'
    .run(location.hash)
)

container = document.getElementById 'app'
tl.run container, (require './vrender-main'), handlers, State
