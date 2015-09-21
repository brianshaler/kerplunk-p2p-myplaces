_ = require 'lodash'
React = require 'react'
moment = require 'moment'

{DOM} = React

flatten = (data, parents = []) ->
  result = []
  if data?.answer
    answer = data.answer
    if answer instanceof Array
      answer = _.map answer, (item) ->
        item._route = parents
        item
    else
      data.answer._route = parents
    result = result.concat answer
  if data?.friends
    for domain, _data of data.friends
      result = result.concat flatten _data, parents.concat domain
  result

reducePlace = (memo, place) ->
  group = memo[place.guid] ? {place: place, items: []}
  if place.items?.length > 0
    group.items = group.items.concat place.items
  memo[place.guid] = group
  memo

module.exports = React.createFactory React.createClass
  getInitialState: ->
    places: @props.places ? []

  componentDidMount: ->
    parameters =
      lng: @props.location[0]
      lat: @props.location[1]
      radius: 200
    url = '/admin/p2p/query/send.json'
    options =
      query: 'myPlaces'
      parameters: JSON.stringify parameters
      degrees: 2
      reduction: 'tree'
      json: true
    @setState
      places: []
    console.log 'query', url, options
    @props.request.post url, options, (err, data) =>
      console.log 'answer', err, data
      flattened = flatten data, [window.location.host]
      routed = _.map flattened, (place) ->
        place.items = _.map place.items, (item) ->
          item._route = place._route
          item
        place
      console.log 'flat?', flattened
      grouped = _.reduce routed, reducePlace, {}
      @setState
        places: _.map grouped, (group) ->
          place = _.clone group.place
          place.items = group.items
          place

  render: ->
    lng = Math.round(@props.location[0] * 100) / 100
    lat = Math.round(@props.location[1] * 100) / 100

    DOM.section
      className: 'content'
    ,
      DOM.h3 null, "Places"
      DOM.p null, "(near #{lng}, #{lat})"
      _.map @state.places, (place) ->
        DOM.div
          key: "place-#{place._id}"
        ,
          DOM.h4 null,
            place.name
            # " (#{place.guid})"
          _.map place.items, (item) ->
            fof = item._route
              .slice 1, item._route.length - 1
              .join ' > '
            DOM.div
              key: "place-#{place._id}-#{item._id}"
            ,
              DOM.strong null,
                item.identity.fullName ? item.identity.nickName
              ' '
              DOM.em null, moment(item.postedAt).fromNow()
              (DOM.em null, " (via #{fof})" if fof.length > 0)
