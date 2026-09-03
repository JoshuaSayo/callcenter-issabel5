const fs = require('fs');
const path = require('path');
const vm = require('vm');

const failures = [];
const requests = [];
const fetches = [];
const elements = {};
let failureHandlers = 0;

function check(condition, message) {
    if (!condition) {
        failures.push(message);
    }
}

function resolved(value) {
    return {
        then: function (callback) {
            try {
                return resolved(callback(value));
            } catch (error) {
                failures.push('client callback threw: ' + error.message);
                return resolved(undefined);
            }
        },
        catch: function () {
            return this;
        },
        fail: function (callback) {
            if (typeof callback === 'function') {
                failureHandlers++;
            }
            return this;
        }
    };
}

function jquery() {
    return {
        ready: function () {}
    };
}

jquery.get = function (url, data, success, dataType) {
    requests.push({
        url: url,
        data: data,
        success: success,
        dataType: dataType
    });
    const rows = [{
        agent: 'Agent/9001',
        lastCall: data.campaigntype === 'incoming'
            ? '2026-09-02 09:15:00'
            : '2026-09-02 09:16:00'
    }];
    rows.find = undefined;
    return resolved({
        status: 'success',
        listaLastCall: rows
    });
};

const context = {
    $: jquery,
    console: {
        log: function () {},
        error: function (message) {
            failures.push('client logged an error: ' + message);
        }
    },
    document: {
        getElementsByClassName: function (name) {
            if (!elements[name]) {
                elements[name] = [{ style: {} }];
            }
            return elements[name];
        }
    },
    fetch: function (url) {
        fetches.push(url);
        return resolved({
            json: function () {
                return {
                    listaLastCall: [{
                        agent: 'Agent/9001',
                        lastCall: 'legacy'
                    }],
                    unavailables: []
                };
            }
        });
    },
    setTimeout: function (callback) {
        callback();
    }
};

vm.createContext(context);
const sourcePath = path.join(
    __dirname,
    '..',
    '..',
    'modules',
    'campaign_monitoring',
    'themes',
    'default',
    'js',
    'javascript.js'
);
vm.runInContext(fs.readFileSync(sourcePath, 'utf8'), context, {
    filename: sourcePath
});

function makeAgents() {
    const model = {
        values: { estado: 'Phone Off' },
        setProperties: function (values) {
            for (const key in values) {
                if (Object.prototype.hasOwnProperty.call(values, key)) {
                    this.values[key] = values[key];
                }
            }
        }
    };

    return {
        model: model,
        collection: {
            findBy: function (key, value) {
                return key === 'canal' && value === 'Agent/9001' ? model : null;
            }
        }
    };
}

const incomingAgents = makeAgents();
const outgoingAgents = makeAgents();
const response = { add: [{ agent: 'Agent/9001' }] };

context.lastCallIncoming(41, response, incomingAgents.collection);
context.lastCallOutgoing(42, response, outgoingAgents.collection);

check(fetches.length === 0,
    'last-call client still used the retired direct endpoint: ' + JSON.stringify(fetches));
check(requests.length === 2,
    'last-call client did not make two authenticated dispatcher requests');

const expectedTypes = ['incoming', 'outgoing'];
for (let i = 0; i < requests.length; i++) {
    const request = requests[i];
    check(request.url === 'index.php',
        'request ' + i + ' did not use index.php');
    check(request.dataType === 'json',
        'request ' + i + ' did not request JSON');
    check(request.success === null,
        'request ' + i + ' used the JSON type as a success callback');
    check(request.data.menu === 'campaign_monitoring',
        'request ' + i + ' omitted the campaign module');
    check(request.data.rawmode === 'yes',
        'request ' + i + ' omitted raw mode');
    check(request.data.action === 'getAgentLastCalls',
        'request ' + i + ' used the wrong action');
    check(request.data.campaigntype === expectedTypes[i],
        'request ' + i + ' used the wrong campaign type');
    check(request.data.campaignid === 41 + i,
        'request ' + i + ' used the wrong campaign ID');
    check(Object.keys(request.data).sort().join(',') ===
        'action,campaignid,campaigntype,menu,rawmode',
        'request ' + i + ' did not use the exact allowed parameter set: ' +
        Object.keys(request.data).sort().join(','));
}
check(failureHandlers === 2,
    'last-call requests did not register transport failure handling');

check(incomingAgents.model.values.desde === '2026-09-02 09:15:00',
    'incoming last-call display changed');
check(outgoingAgents.model.values.desde === '2026-09-02 09:16:00',
    'outgoing last-call display changed');
check(incomingAgents.model.values.estado === 'Phone Off' &&
    outgoingAgents.model.values.estado === 'Phone Off',
    'last-call updates overwrote the server-owned phone state');

context.agentColor('Phone Off', 'Agent/9001');
check(elements['Agent/9001'][0].style.backgroundColor === '#f33',
    'Phone Off was not colored as disconnected');

const update = context.agentUpdateColor('Phone Off', 'Agent/9002');
check(elements['Agent/9002'][0].style.backgroundColor === '#f33',
    'Phone Off update was not colored as disconnected');
check(update.statusImage.indexOf('agent-disconected.png') !== -1,
    'Phone Off update did not use the disconnected icon');

if (failures.length > 0) {
    console.error('FAIL monitoring_client_boundary: ' + failures.join('\n'));
    process.exit(1);
}

console.log('PASS monitoring_client_boundary');
