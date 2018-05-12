document.addEventListener('DOMContentLoaded', function() {
  var html = document.getElementsByTagName('html')[0];
  if(html.className != 'dashboard-controller show-action') {
    return;
  }

  var creditCardForm = document.getElementById('credit-card');
  var stripe = Stripe(creditCardForm.getAttribute('api-key'));
  var elements = stripe.elements();
  var creditCard = elements.create('card');
  var hasCreditCard = creditCardForm.getAttribute('data-found') === 'true';

  var api = {
    query: function(params) {
      var queryString = [];
      for(var key in params) {
        if(params.hasOwnProperty(key)) {
          queryString.push(encodeURIComponent(key) + "=" + encodeURIComponent(params[key]))
        }
      }
      return queryString.join('&');
    },
    get: function(path, params) {
      if(params) {
        path = path + '?' + api.query(params);
      }
      return api.request('get', path);
    },
    post: function(path, params) {
      return api.request('post', path, params);
    },
    put: function(path, params) {
      return api.request('put', path, params);
    },
    delete: function(path, params) {
      return api.request('delete', path, params);
    },
    handleError: function(response) {
      if (!response.ok) {
        return response.json().then(function(err) {
          throw err.errors;
        })
      }
      return response
    },
    request: function(method, path, params) {
      var opts = {
        method: method.toUpperCase(),
        credentials: 'same-origin',
        headers: {},
      };

      if(method != 'get' && params) {
        opts.body = JSON.stringify(params);
        opts.headers['Content-Type'] = 'application/json';
      };

      return fetch(path, opts).then(api.handleError).then(function(response) {
        return response.json();
      });
    },
  };

  var errorsStore = {
    state: {
      errors: []
    },
    setErrorsAction (newErrors) {
      this.state.errors.splice(0, this.state.errors.length)

      var self = this;

      // { "user": ["some error messages"], "eamil": ["some error messages"] } }
      // のように返ってくるエラーレスポンスから、メッセージだけを取り出してself.state.errorsに詰める
      Object.keys(newErrors).forEach(function(key) {
        Array.prototype.push.apply(self.state.errors, newErrors[key]);
      });
    },
    clearErrorsAction () {
      this.state.errors.splice(0, this.state.errors.length)
    }
  };

  Vue.component('error-box', {
    data: function () {
      return {
        errorsStoreState: errorsStore.state
      };
    },
    methods: {
      hide: function() {
        errorsStore.clearErrorsAction();
      },
    },
    template: `
      <article class="message is-danger" v-if="errorsStoreState.errors.length != 0">
        <div class="message-header">
          <p>Error</p>
          <button class="delete" aria-label="delete" @click="hide"></button>
        </div>
        <div class="message-body">
          <ul>
            <li v-for="error in errorsStoreState.errors">{{ error }}</li>
          </ul>
        </div>
      </article>`
  });

  var dashboard = new Vue({
    el: '#dashboard',
    data: {
      currentTab: 'remits',
      amount: 0,
      charges: [],
      charge_histories: [],
      recvRemits: [],
      sentRemits: [],
      hasCreditCard: hasCreditCard,
      isRegisteringCreditCard: false,
      isActiveNewRemitForm: false,
      isCharging: false,
      target: "",
      user: {
        id: 0,
        email: "",
        nickname: "",
      },
      newRemitRequest: {
        emails: [],
        amount: 0,
      },
    },

    beforeMount: function() {
      var self = this;
      api.get('/api/user').then(function(json) {
        self.user = json;
        self.setUpReceivedRemitRequestsStream(self.user.id);
      });

      api.get('/api/charges').then(function(json) {
        self.charges = self.prettifyChargesResponse(json.charges);
      });

      api.get('/api/charge_histories').then(function(json) {
        self.charge_histories = self.prettifyChargesResponse(json.charges);
      });

      api.get('/api/balance').then(function(json) {
        self.amount = json.amount
      })

      this.refreshRemitRequests();
    },
    mounted: function() {
      var form = document.getElementById('credit-card');
      if(form){ creditCard.mount(form); }
    },
    methods: {
      prettifyChargesResponse: function(charges) {
        for (var i = 0; i < charges.length; i++){
          var strDateTime = charges[i]['created_at'];
          var myDate = new Date(strDateTime);
          charges[i]['created_at'] = myDate.toLocaleString();
        }
        return charges;
      },
      showError: function(errors) {
        errorsStore.setErrorsAction(errors)
      },
      removeError: function(errors) {
        errorsStore.clearErrorsAction(errors)
      },
      charge: function(amount, event) {
        if(event) { event.preventDefault(); }

        this.isCharging = true;

        var self = this;
        api.post('/api/charges', { amount: amount }).
          then(function(json) {
            var strDateTime = json['created_at'];
            json['created_at'] = new Date(strDateTime).toLocaleString();
            self.charges.unshift(json);
          }).
          finally(function(){
            self.isCharging = false

            // Charge完了までポーリングを開始する
            var timer = setInterval(function() {
              api.get('/api/charges').then(function(json) {
                self.charges = self.prettifyChargesResponse(json.charges);

                // Chargeがなくなったことは、chargeが完了してcharge historyが作られたことを意味する
                if (self.charges.length == 0) {
                  clearInterval(timer);
                  api.get('/api/charge_histories').then(function(json) {
                    self.charge_histories = self.prettifyChargesResponse(json.charges);
                  })
                  api.get('/api/balance').then(function(json) {
                    self.amount = json.amount
                  })
                }
              });
            }, 3000);
          }).
          catch(function(err) {
            self.showError(errors);
          });


      },
      registerCreditCard: function(event) {
        if(event) { event.preventDefault(); }

        this.isRegisteringCreditCard = true;

        var self = this;
        stripe.createToken(creditCard).
          then(function(result) {
            return api.post('/api/credit_card', { credit_card: { source: result.token.id }});
          }).
          then(function() {
            self.hasCreditCard = true;
          }).
          finally(function() {
            self.isRegisteringCreditCard = false;
          });
      },
      addTarget: function(event) {
        if(event) { event.preventDefault(); }

        if(!this.newRemitRequest.emails.includes(this.target)) {
          this.newRemitRequest.emails.push(this.target);
        }
      },
      removeTarget: function(email, event) {
        if(event) { event.preventDefault(); }

        this.newRemitRequest.emails = this.newRemitRequest.emails.filter(function(e) {
          return e != email;
        });
      },
      sendRemitRequest: function(event) {
        if(event) { event.preventDefault(); }

        var self = this;
        api.post('/api/remit_requests', this.newRemitRequest).
          then(function() {
            self.newRemitRequest = {
              emails: [],
              amount: 0,
            };
            self.target = '';
            self.isActiveNewRemitForm = false;
          });
      },
      accept: function(id, event) {
        if(event) { event.preventDefault(); }

        var self = this;
        api.post('/api/remit_requests/' + id + '/accept').
          then(function() {
            self.recvRemits = self.recvRemits.filter(function(r) {
              if(r.id != id) {
                return true
              } else {
                self.amount -= r.amount;
                return false
              }
            });
          });
      },
      reject: function(id, event) {
        if(event) { event.preventDefault(); }

        var self = this;
        api.post('/api/remit_requests/' + id + '/reject').
          then(function() {
            self.recvRemits = self.recvRemits.filter(function(r) {
              return r.id != id;
            });
          });
      },
      updateUser: function(event) {
        if(event) { event.preventDefault(); }

        var self = this;
        api.put('/api/user', { user: this.user }).
          then(function(json) {
            self.user = json;
          });
      },
      refreshRemitRequests: function() {
        var self = this;
        api.get('/api/remit_requests', { status: 'outstanding' }).
          then(function(json) {
            self.recvRemits = json;
          });
      },
      setUpReceivedRemitRequestsStream: function(user_id) {
        let es = new EventSource('http://localhost:3001/sse/user/' + user_id + '/received_remit_requests');

        var self = this;
        es.addEventListener('message', event => {
          self.refreshRemitRequests();
        });
      }
    }
  });
});
