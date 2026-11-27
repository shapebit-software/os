.pragma library
// What features add to the shell (Feature.qml), merged into the shell's own:
// Settings' sections, its sidebar's groups, its pages, and the keyboard
// shortcuts. Pure, so that tst_features.qml checks it.

// The rows that features add to sections and pages not theirs: {id: rows}.
function rows(features) {
    const result = {};
    for (const feature of features) {
        for (const [id, added] of Object.entries(feature.rows ?? {}))
            result[id] = (result[id] ?? []).concat(added);
    }
    return result;
}

// Those of `list`, {id: rows} or [{id, rows}], with the rows features add to
// each, after its own.
function withRows(list, added) {
    const add = (id, own) => added[id] ? (own ?? []).concat(added[id]) : own;
    if (Array.isArray(list))
        return list.map(s => added[s.id] ? Object.assign({}, s, { rows: add(s.id, s.rows) }) : s);
    const result = {};
    for (const [id, own] of Object.entries(list))
        result[id] = add(id, own);
    return result;
}

// The shell's sections, then each feature's, with the rows features add.
function sections(own, features) {
    return withRows(own.concat(...features.map(f => f.sections ?? [])), rows(features));
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
    return withRows(result, rows(features));
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
