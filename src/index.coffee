_ = require 'lodash'
Promise = require 'when'

module.exports = (System) ->
  ActivityItem = System.getModel 'ActivityItem'
  Place = System.getModel 'Place'

  getMyPlaces = (data) ->
    deferred = Promise.defer()
    lng = data?.parameters?.lng
    lat = data?.parameters?.lat
    radius = data?.parameters?.radius
    return data unless lat and lng and radius
    lng = parseFloat lng
    lat = parseFloat lat
    radius = parseFloat radius
    where =
      location:
        $near:
          $geometry:
            type: 'Point'
            coordinates: [lng, lat]
          $maxDistance: radius * 1000
    me = System.getMe()
    console.log 'where',
      identity: me._id
      'attributes.place':
        '$in': 'placeIds'

    Place
    .where where
    .limit 100
    .find (err, places) ->
      return deferred.reject err if err
      return deferred.resolve data unless places?.length > 0
      placeIds = _.map places, '_id'
      me = System.getMe()
      where =
        identity: me._id
        'attributes.place':
          '$in': placeIds
      ActivityItem
      .where where
      .sort
        postedAt: -1
      .populate 'identity'
      .find (err, items) ->
        # console.log 'nearby items', items?.length, where
        Promise.all _.map items, (item) ->
          if item.toObject
            item = item.toObject()
          delete item.data
          delete item.identity.data if item.identity?.data?
          if item.activity?.length > 0
            item.activity = _.map item.activity, (subItem) ->
              if subItem.toObject
                subItem = subItem.toObject()
              delete subItem.data
              subItem
          item
          System.do 'activityItem.populate', item
        .then (items) ->
          places = _ places
            .map (place) ->
              if place.toObject
                place = place.toObject()
              placeId = String place._id
              place.items = _.filter items, (item) ->
                String(item.attributes.place) == placeId
              place
            .filter (place) ->
              place.items?.length > 0
            # .map 'name'
            .value()
          data.answer = places
          deferred.resolve data
    deferred.promise

  showPlaces = (req, res, next) ->
    data = {}
    System.do 'me.location.last', {}
    .then (info) ->
      unless info?.location?.length == 2
        info =
          location: [-111.94, 33.42]
      return next new Error 'no location?' unless info?.location?.length == 2
      data.location = info.location
      data.items = []
      res.render 'places', data

  globals:
    public:
      nav:
        P2P:
          Places: '/admin/p2p/places'

  events:
    p2p:
      query:
        myPlaces:
          do: getMyPlaces

  routes:
    admin:
      '/admin/p2p/places': 'places'

  handlers:
    places: showPlaces
