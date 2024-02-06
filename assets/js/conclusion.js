/* eslint-env jquery */
/* global Chart */

import { listArgumentUrls, airddataUrl, findArgumentByPath } from './common.js'

function chartOptionsWithTitle(title) {
  return {
    plugins: {
      title: {
        text: title,
        display: true,
        position: 'top',
      },
      legend: {
        display: false
      },
      labels: {
        render: 'image'
      }
    },
    scales: {
      y: {
        beginAtZero: true,
        ticks: {
          stepSize: 1
        }
      },
      x: {
        grid: {
          display: false
        }
      }
    }
  }
}

function chartMax(arr) {
  const maxVal = Math.max(...arr)
  return Math.round(maxVal * 1.1) + 1
}

export function addConclusionContent(args, path) {
  if (!path.match(/conclusion/)) return

  fetch(airddataUrl('answers', 'GET'), {
    method: 'GET',
  })
  .then(response => response.json())
  .then(data => {
    const within50 = findArgumentByPath(args, '/perspectives/within-50-years')
    const moreThan50 = findArgumentByPath(args, '/perspectives/more-than-50-years')
    const never = findArgumentByPath(args, '/perspectives/never')

    const chosenOpt = {
      src: "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjQiIGhlaWdodD0iMjQiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgZmlsbC1ydWxlPSJldmVub2RkIiBjbGlwLXJ1bGU9ImV2ZW5vZGQiPjxwYXRoIGQ9Ik0xMiAwYzYuNjIzIDAgMTIgNS4zNzcgMTIgMTJzLTUuMzc3IDEyLTEyIDEyLTEyLTUuMzc3LTEyLTEyIDUuMzc3LTEyIDEyLTEyem0wIDFjNi4wNzEgMCAxMSA0LjkyOSAxMSAxMXMtNC45MjkgMTEtMTEgMTEtMTEtNC45MjktMTEtMTEgNC45MjktMTEgMTEtMTF6bTcgNy40NTdsLTkuMDA1IDkuNTY1LTQuOTk1LTUuODY1Ljc2MS0uNjQ5IDQuMjcxIDUuMDE2IDguMjQtOC43NTIuNzI4LjY4NXoiLz48L3N2Zz4=",
      width: 16,
      height: 16
    }

    let chart
    let imagesList
    let div

    if (within50.agreement === 'agree') {
      imagesList = [chosenOpt]
    } else if (moreThan50.agreement === 'agree') {
      imagesList = [null, chosenOpt]
    } else if (never.agreement === 'disagree') {
      imagesList = [null, null, chosenOpt]
    } else {
      imagesList = []
    }

    let chartOptions = chartOptionsWithTitle('When AGI?')
    chartOptions.plugins.labels = {
      render: 'image',
      images: imagesList,
    }

    chartOptions.scales.y.max = chartMax([
      data['when-agi']['within-50-years'],
      data['when-agi']['after-50-years'],
      data['when-agi']['never']
    ])

    $('<div class="charts" />').appendTo('.page-content');
    div = $('<div />').appendTo('.charts');
    chart = $('<canvas />').appendTo(div);
    new Chart(chart, {
      type: 'bar',
      data: {
        labels: ['Within 50 Years', 'After 50 Years', 'Never'],
        datasets: [{
          label: 'When AGI?',
          data: [
            data['when-agi']['within-50-years'],
            data['when-agi']['after-50-years'],
            data['when-agi']['never']
          ],
          backgroundColor: ['#8d8', '#8d8', '#d88'],
          borderWidth: 1
        }]
      },
      options: chartOptions
    })

    const chartKeys = [
      'the-alignment-problem',
      'instrumental-incentives',
      'threat-models',
      'pursuing-safety-work'
    ]
    const chartTitles = [
      'The Alignment Problem',
      'Instrumental Incentives',
      'Threat Models',
      'Pursuing Safety Work'
    ]
    chartKeys.forEach((chartKey, i) => {
      const currentArg = findArgumentByPath(args, `/perspectives/${chartKey}`)

      switch (currentArg.agreement) {
        case 'agree':
          imagesList = [chosenOpt]
          break;
        case 'disagree':
          imagesList = [null, chosenOpt]
          break;
        default:
          imagesList = []
      }

      let chartOptions = chartOptionsWithTitle(chartTitles[i])
      chartOptions.plugins.labels = {
        render: 'image',
        images: imagesList,
      }

      chartOptions.scales.y.max = chartMax([data[chartKey]['agree'], data[chartKey]['disagree']])

      div = $('<div />').appendTo('.charts');
      chart = $('<canvas />').appendTo(div);

      new Chart(chart, {
        type: 'bar',
        data: {
          labels: ['Agree', 'Disagree'],
          datasets: [{
            label: chartTitles[i],
            data: [data[chartKey]['agree'], data[chartKey]['disagree']],
            backgroundColor: ['#8d8', '#d88'],
            borderWidth: 1
          }]
        },
        options: chartOptions
      })
    })

    addAgreementsTable(args)
    addConclusionCommentsLink()
  })
}

function capitalize(s) {
  return s.substr(0, 1).toUpperCase() + s.substr(1)
}

function addConclusionCommentsLink() {
  $(`<p style="margin-top: 1em"><a href="${window.site_baseurl}/comments" class="button small">Read the comments</a></p><h2>What's next? Read more at: </h2><p><div class="row"><div class="4u 12u$(medium)"><a href='../interviews' class='button'>Interviews</a></div><div class="4u 12u$(medium)"><a href='../resources' class='button'>Resources</a></div></div></p>`).appendTo('.page-content');
}

function addAgreementsTable(args) {
  const agreementsTable = $("<div class='agreements-table'></div>")
  let answersCount = 0
  const skipUrls = ['within-50-years', 'more-than-50-years', 'never']
  listArgumentUrls().forEach((url) => {
    if (!url) return
    if (skipUrls.includes(url)) return

    const argument = findArgumentByPath(args, "/perspectives/" + url)

    if (!argument.agreement) return

    let agreementClass = argument.agreement
    if (url === 'when-generally-capable-ai') {
      const within50 = findArgumentByPath(args, "/perspectives/within-50-years")
      const after50 = findArgumentByPath(args, "/perspectives/more-than-50-years")
      const never = findArgumentByPath(args, "/perspectives/never")
      if (within50.agreement === 'agree') {
        argument.agreement = 'Within 50 Years'
        agreementClass = 'agree'
      } else if (after50.agreement === 'agree') {
        argument.agreement = 'After 50 Years'
        agreementClass = 'agree'
      } else if (never.agreement === 'disagree') {
        argument.agreement = 'Never'
        agreementClass = 'disagree'
      }
    }

    const row = $('<div />')
    $(`<div class="page-name">${argument.name}</div>`).appendTo(row)
    $(`<div class="agreement ${agreementClass}"><span>${capitalize(argument.agreement)}</span></div>`).appendTo(row)
    row.appendTo(agreementsTable)
    answersCount++
  })
  if (answersCount > 0) {
    $("<div class='agreement-table-heading'>Your answers</div>").appendTo('.page-content')
    agreementsTable.appendTo('.page-content')
  }
}
