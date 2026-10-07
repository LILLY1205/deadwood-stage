function post(endpoint, data) {
    return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {})
    }).catch(error => {
        console.error(`[Deadwood Stage] Post error ${endpoint}:`, error);
    });
}

function closeUI() {
    document.getElementById('stagecoachMenu').classList.remove('visible');
    post('closeUI', {});
}

function showView(viewId) {
    document.getElementById('noGroupView').style.display = 'none';
    document.getElementById('inGroupView').style.display = 'none';
    document.getElementById('missionView').style.display = 'none';
    document.getElementById(viewId).style.display = 'block';
}

function createGroup() {
    closeUI();
    post('createGroup', {});
}

function joinGroup() {
    const groupId = document.getElementById('groupIdInput').value;
    if (!groupId || groupId < 1) return;
    closeUI();
    post('joinGroup', { groupId: groupId });
}

function startMission() {
    closeUI();
    post('startMission', {});
}

function leaveGroup() {
    closeUI();
    post('leaveGroup', {});
}

function endMission() {
    closeUI();
    post('endMission', {});
}

function startStagecoach() {
    closeUI();
    post('startStagecoach', {});
}

function speedUp() {
    closeUI();
    post('speedUp', {});
}

function slowDown() {
    closeUI();
    post('slowDown', {});
}

function haltStagecoach() {
    closeUI();
    post('haltStagecoach', {});
}

function holdPosition() {
    closeUI();
    post('holdPosition', {});
}

window.addEventListener('message', function(event) {
    const data = event.data;

    switch (data.action) {
        case 'openStagecoachMenu':
            document.getElementById('stagecoachMenu').classList.add('visible');
            document.getElementById('groupIdInput').value = '';

            if (data.missionActive) {
                showView('missionView');
            } else if (data.inGroup) {
                showView('inGroupView');
                document.getElementById('displayGroupId').textContent = data.groupId || '-';
            } else {
                showView('noGroupView');
            }
            break;

        case 'updateGroupInfo':
            if (data.groupId) {
                document.getElementById('displayGroupId').textContent = data.groupId;
            }
            break;

        case 'closeAll':
            document.getElementById('stagecoachMenu').classList.remove('visible');
            break;
    }
});

document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        closeUI();
    }
});
