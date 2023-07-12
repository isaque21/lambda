function getCurrDate(){
  var currData = new Date();
  var currMonth = currData.getMonth() + 1; // Os meses são indexados de 0 a 11, então adicionamos 1 para obter o mês atual
  var currYear = currData.getFullYear();

  return {
    mes: currMonth,
    ano: currYear
  };
}

function getMonthNames(mes) {
  var meses = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
  return meses[mes];
}

function readCSVFile(fileName) {
    $.ajax({
      url: `data/availability-report-${fileName}.csv`,
      dataType: 'text',
      success: function(data) {
        var parsedData = Papa.parse(data, { skipEmptyLines: true }).data;

        data = null;
        parsedData.shift(); // Remove a primeira linha
  
        var mainCharts = $('#main-charts'); // Elemento div onde os arrays serão impressos
        var mainTables = $('#availability-table'); // Elemento div onde os arrays serão impressos
        // Limpa o conteúdo atual da div
        mainCharts.empty();
        mainTables.empty();
        // mainCharts.append('');
        var canvasCount = 0;
        // Itera sobre os arrays e imprime cada um em uma div separada
        parsedData.forEach(function(array) {
            var account = array[0];
            var region = array[1];
            var instanceName = array[2];
            var instanceId = array[3];
            var platform = array[4];
            var type = array[5];
            var uptimeHours = array[6];
            var downtimeHours = array[7];
            var percentage = array[8];
            var hoursUsed = array[9];
            var startDate = array[10];
            var endDate = array[11];


            var divCharts = $(`<div id="chart" class="div-chart col-md-4">
                <div class="row">
                    <p class="chart-header">Name: <span>${instanceName}</span> | ID: <span>${instanceId}</span></p>
                    <div class="col-md-7">
                        <div id="chartContainer${canvasCount}">
                          <div id="canvas" height="250">
                          </div>
                        </div>
                    </div>
                    <div class="chart-details col-md-5">
                        <h4>Availability percentage:</h4>
                        <p><span class="percent">${percentage}%</span>
                        <h4>Availability hours:</h4> 
                        <p>Uptime: <span class="uptime">${uptimeHours}</span></p>
                        <p>Downtime: <span class="downtime">${downtimeHours}</span></p>
                        <p>Hours used: ${hoursUsed}</p>

                    </div>
                </div>
              </div>`); // Cria uma nova div com o conteúdo do array
            mainCharts.append(divCharts); // Adiciona a nova div ao container
            
            
            var label = [uptimeHours, downtimeHours]
            createChart(label, uptimeHours, downtimeHours, canvasCount);


            var divTables = $(`
              <tr>
                <th scope="row">${canvasCount}</th>
                <td>${account}</td>
                <td>${region}</td>
                <td>${instanceName}</td>
                <td>${instanceId}</td>
                <td>${platform}</td>
                <td>${type}</td>
                <td>${uptimeHours}</td>
                <td>${downtimeHours}</td>
                <td>${percentage}%</td>
                <td>${hoursUsed}</td>
                <td>${startDate}</td>
                <td>${endDate}</td>
              </tr>
        `); // Cria uma nova div com o conteúdo do array

        mainTables.append(divTables); // Adiciona a nova div ao container

        canvasCount += 1;
            
        });
      },
      error: function() {

        var mainCharts = $('#main-charts'); // Elemento div onde os arrays serão impressos
        var mainTables = $('#availability-table'); // Elemento div onde os arrays serão impressos
        // Limpa o conteúdo atual da div
        mainCharts.empty();
        mainTables.empty();

        var divCharts = $(`<div id="main-data" class="div-chart col-md-4">
                <p>No data found :/</p>
              </div>`); // Cria uma nova div com o conteúdo do array
        mainCharts.append(divCharts); // Adiciona a nova div ao container

        var linkElement = document.getElementById("download-csv");
        var filePath = `#`;
        linkElement.setAttribute("href", filePath);
      }
    });
}


function createChart(label, uptimeMinutes, downtimeMinutes, canvasCount) {
    
  // Crie um elemento <canvas> no HTML para renderizar o gráfico
  var canvas = $('<canvas>');

  $(`#chartContainer${canvasCount}`).append(canvas);

  // Configure o contexto do gráfico
  var ctx = canvas[0].getContext('2d');

  // Crie o gráfico utilizando o Chart.js
  new Chart(ctx, {
    type: 'doughnut',
    data: {
      labels: ['Uptime', 'Downtime'],
      datasets: [{
        label: 'Horas',
        data: [uptimeMinutes.replace(':', '.'), downtimeMinutes.replace(':','.')],
        backgroundColor: ['rgb(50,140,209, 1)', 'rgba(183, 178, 181, 0.26)'],
        borderColor: ['rgb(255,255,255, 1)', 'rgba(31, 119, 180, 0.1)'],
        borderWidth: 1
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      // Outras opções de configuração do gráfico podem ser adicionadas aqui
    }
  });
}

$(document).ready(function() {

  $("#charts").click(function(e) {
    e.preventDefault();
    
    // Esconde a div com o id "div1"
    $("#main-table").hide();
    
    // Mostra a div com o id "div2"
    $("#main-charts").show();
  });

  $("#tables").click(function(e) {
    e.preventDefault();
    
    // Esconde a div com o id "div1"
    $("#main-charts").hide();
    
    // Mostra a div com o id "div2"
    $("#main-table").show();
  });

  $("#period-month").change(function(e) {
        
    var selectedDate = $(this).val();
    var linkElement = document.getElementById("download-csv");
    var filePath = `data/availability-report-${selectedDate}.csv`;
    linkElement.setAttribute("href", filePath);

    readCSVFile(selectedDate)
  });

  var mes = getCurrDate().mes;
  var ano = getCurrDate().ano;
  var fileName = mes + "-" + ano;

var currData = new Date();

for (var i = 0; i < 12; i++) {
  var currMonth = currData.getMonth() - (i-1);
  var currYear = currData.getFullYear();
  if (currMonth <= 0) {
    currMonth += 12;
    currYear--;
  }
  var monthName = getMonthNames(currMonth-1);
  var monthYear = monthName + " " + currYear;

  var optionMonth = $("<option></option>").text(monthYear).attr("value", currMonth + "-" + currYear);

  $("#period-month").append(optionMonth);
  }

  var linkElement = document.getElementById("download-csv");
  var filePath = `data/availability-report-${fileName}.csv`;
  linkElement.setAttribute("href", filePath);

  readCSVFile(fileName);

});

