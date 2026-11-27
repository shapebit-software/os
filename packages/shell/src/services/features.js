.pragma library
// What features add to the shell (Feature.qml), merged into the shell's own:
// Settings' sections, its sidebar's groups, its pages, and the keyboard
// shortcuts. Pure, so that tst_features.qml checks it.

// The shell's sections, then each feature's.
function sections(own, features) {
    return own.concat(...features.map(f => f.sections ?? []));
}

// The sidebar's groups, with each feature's sections in theirs: in group
// `group` (the last when there is none, or no such), after section `after`,
// or last.
function groups(own, features) {
    const result = own.map(group => group.slice());
    for (const feature of features) {
        for (const section of feature.sections ?? []) {
            const group = result[Math.min(section.group ?? result.length - 1, result.length - 1)];
            const at = section.after ? group.indexOf(section.after) : -1;
            group.splice(at >= 0 ? at + 1 : group.length, 0, section.id);
        }
    }
    return result;
}

// The pages, as Settings keeps them: {id: [title, section]}.
function pages(own, features) {
    const result = Object.assign({}, own);
    for (const feature of features) {
        for (const [id, page] of Object.entries(feature.pages ?? {}))
            result[id] = [page.title, page.section];
    }
    return result;
}

// The pages that are rows, as a section's: {id: rows}.
function pageRows(own, features) {
    const result = Object.assign({}, own);
    for (const feature of features) {
        for (const [id, page] of Object.entries(feature.pages ?? {})) {
            if (page.rows)
                result[id] = page.rows;
        }
    }
    return result;
}

// The pages of their own, which Settings loads: [{id, component}].
function pageComponents(features) {
    const result = [];
    for (const feature of features) {
        for (const [id, page] of Object.entries(feature.pages ?? {})) {
            if (page.component)
                result.push({ id: id, component: page.component });
        }
    }
    return result;
}

// The bars' items that features add: {name: {icon, component}}.
function items(features) {
    return Object.assign({}, ...features.map(f => f.items ?? {}));
}

// The quick actions that features add, in their order: [{name, icon, tap}].
function actions(features) {
    return [].concat(...features.map(f => f.actions ?? []));
}

// What one feature does for others, by name, or null: the first that does.
function provided(features, name) {
    return features.map(f => (f.provides ?? {})[name]).find(f => f) ?? null;
}

// The keyboard shortcuts that features answer: {name: function}; a later
// feature's takes a name over an earlier one's.
function shortcuts(features) {
    return Object.assign({}, ...features.map(f => f.shortcuts ?? {}));
}
