#!/usr/bin/env bash

LOCAL_GRADLE_REPO=""

setup() {
    ORIG_WD=$(pwd)
    source ./gradle-tab-completion.bash
    CASHE_FILE="testCache"
}

teardown() {
    cd $ORIG_WD
    rm -f ./gradlew
    rm -f ./build.gradle
    rm -f $CASHE_FILE
    # rm -f $HOME/.gradle/bash_completion.cache
}

test__should_support_default_gradle_installation() {

    local result=$(getGradleCommand)

    local exp='gradle'
    if [[ $result != $exp ]]; then
        fail "expected '$exp', got '$result'"
    fi
}

test__should_support_gradle_wrapper() {
    touch ./gradlew
    chmod +x ./gradlew

    local result=$(getGradleCommand)

    local exp='./gradlew'
    if [[ $result != $exp ]]; then
        fail "expected '$exp', got '$result'"
    fi
}

test__should_allow_requesting_tasks_from_gradle() {
    cd $LOCAL_GRADLE_REPO

    result=$(requestTasksFromGradle)

    exp='assemble build buildDependents buildNeeded classes clean j9Classes jar testClasses init wrapper javadoc buildEnvironment components dependencies dependencyInsight dependentComponents help model projects properties tasks cleanEclipse cleanIdea eclipse idea uploadArchives check test backport compressTests deploy deployDownloadedArtifacts deploySpeechAdi deploySpeechRevo dialogTests downloadArtifactsAdi_AS downloadArtifactsAdi_CLU22 downloadArtifactsAdi_EU downloadArtifactsAdi_NAR downloadArtifactsRevo_AS downloadArtifactsRevo_CLU22 downloadArtifactsRevo_EU downloadArtifactsRevo_NAR removeSpeechJars'
    if [[ $result != $exp ]]; then
        fail "expected: '$exp'\n    got:      '$result'"
    fi
}

test__should_get_tasks_from_a_heading_in_task_output() {
    result=$(parseGradleTaskOutput "$(cat ./t/tasks-one-heading.out)")

    exp='assemble build buildDependents buildNeeded classes clean j9Classes jar testClasses'
    if [[ $result != $exp ]]; then
        fail "expected: '$exp'\n    got: '$result'"
    fi
}

test__should_handle_multiple_headings_and_noise_in_task_output() {
    result=$(parseGradleTaskOutput "$(cat ./t/tasks-full.out)")

    exp='assemble build buildDependents buildNeeded classes clean j9Classes jar testClasses init wrapper javadoc buildEnvironment components dependencies dependencyInsight dependentComponents help model projects properties tasks cleanEclipse cleanIdea eclipse idea uploadArchives check test backport compressTests deploy deployDownloadedArtifacts deploySpeechAdi deploySpeechRevo dialogTests'
    if [[ $result != $exp ]]; then
        fail "expected: '$exp'\n    got: '$result'"
    fi
}

test_readCacheForCwd() {
    cd $LOCAL_GRADLE_REPO

    local cwd=$(pwd)
    local hashString=$( find . -name build.gradle 2> /dev/null \
            | xargs cat \
            | git hash-object --stdin)
    local commands="tasks build etc"
    echo "$cwd|$hashString|$commands" > $CASHE_FILE
    echo "./other/dir|$hashString|$commands" >> $CASHE_FILE

    local result=$(readCacheForCwd)

    IFS='|' read -ra resultArray <<< "$result"
    if [[ $cwd != ${resultArray[0]} ]]; then
        fail "expected '$cwd', got '${resultArray[0]}'"
    fi

    if [[ $hashString != ${resultArray[1]} ]]; then
        fail "expected '$hashString', got '${resultArray[1]}'"
    fi

    if [[ $commands != ${resultArray[2]} ]]; then
        fail "expected '$cwd', got '${resultArray[2]}'"
    fi
}

test_readCacheForCwd_shouldReturnEmptyOnError() {
    local result=$(readCacheForCwd)

    if [[ $result != '' ]]; then
        fail "expected '', got '$result'"
    fi
}

test_getGradleTasksFromCache() {
    tasks='testA testB btest module\:project'
    writeTasksToCache $tasks

    result=$(getGradleTasksFromCache)

    if [[ $result != $tasks ]]; then
        fail "expected '$tasks', got '$result'"
    fi
}

test_getGradleTasksFromCache_shouldReturnEmptyForCacheMiss() {
    makeCacheWithTasks "testA testB btest"

    echo "//something" >> ./build.gradle # changing the repo, invalidating the cache
    result=$(getGradleTasksFromCache)

    if [[ $result != "" ]]; then
        fail "expected '', got '$result'"
    fi
}

test_writeTasksToCache() {
    touch ./build.gradle
    tasks="testA testB btest"

    writeTasksToCache $tasks

    result=$(readCacheForCwd)

    gradleFileHash=$(getGradleChangesHash)
    cacheString="$(pwd)|$gradleFileHash|$tasks"
    if [[ $result != $cacheString ]]; then
        fail "expected: '$cacheString', got '$result'"
    fi
}

test_writeTasksToCache_shouldOverwriteOldCacheForPath() {
    touch ./build.gradle
    tasks="testA testB btest"
    makeCacheWithTasks $tasks

    writeTasksToCache $tasks

    local cwd=$(pwd)
    local pathCount=0
    while read cacheLine || [[ -n $cacheLine ]]; do
        if [[ $cacheLine == "$cwd"* ]]; then
            pathCount=$((pathCount+1))
        fi
    done <$CASHE_FILE

    if [[ $pathCount > 1 ]]; then
        fail "expected: 1 cache recort, got '$pathCount'"
    fi
}

makeCacheWithTasks() {
    local cwd=$(pwd)
    local hashString=$( find . -name build.gradle 2> /dev/null \
            | xargs cat \
            | git hash-object --stdin)
    echo "$cwd|$hashString|$@" > $CASHE_FILE
}