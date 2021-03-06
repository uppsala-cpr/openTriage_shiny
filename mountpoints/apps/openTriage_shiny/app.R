
library(shiny)
library(jsonlite)
library(lubridate)
library(httr)

# Set this if you're using a different framework
fw_url = "https://raw.githubusercontent.com/dnspangler/openTriage/master/frameworks/uppsala_vitals"

# Set this if you're not running this on the same server as the openTriage back-end
server_url = "localhost:443"
httr::set_config(config(ssl_verifypeer = 0L))



model_props = fromJSON(paste0(fw_url,"/models/model_props.json"))
pretty_names = unlist(fromJSON(paste0(fw_url,"/models/pretty_names.json")))

feats = data.frame(var = names(model_props$feat_props$gain),
                   gain = unlist(model_props$feat_props$gain),
                   stringsAsFactors = F)

feats = merge(feats,
              data.frame(var = names(pretty_names),
                         name = pretty_names),
                         stringsAsFactors = F)

feats = feats[rev(order(feats$gain)),]

cat_names = gsub("disp_cats_","",feats$var)[grepl("disp_cats_",feats$var)]
names(cat_names) = feats$name[grepl("disp_cats_",feats$var)]

ui <- fluidPage(

    titlePanel("openTriage - Uppsala Vitals demo"),

    sidebarLayout(
        #actionButton("predict","Predict"),
        sidebarPanel(
            sliderInput("disp_age",
                        "Patient Age",
                        min = 0,
                        max = 100,
                        value = model_props$feat_props$median$disp_age),
            radioButtons("disp_gender",
                         "Patient Gender",
                         choices = list("Male"=0,"Female"=1)),
            selectInput("disp_cats",
                        "Dispatch Categories",
                        choices = cat_names,
                        multiple = T),
            radioButtons("disp_prio",
                         "Dispatch Priority",
                         choices = list("1A"=1,"1B"=2,"2A"=3,"2B"=4,"Referral"=7),
                         selected = model_props$feat_props$median$disp_prio),
            radioButtons("eval_avpu",
                         "Level of Consciousness (AVPU)",
                         choices = list("Alert"="A","Verbal"="V","Pain"="P","Unconscious"="U"),
                         selected = "A"),
            sliderInput("eval_breaths",
                        "Breathing rate",
                        min = 0,
                        max = 50,
                        value = model_props$feat_props$median$eval_breaths),
            sliderInput("eval_spo2",
                        "Oxygen saturation (spo2)",
                        min = 50,
                        max = 100,
                        value = model_props$feat_props$median$eval_spo2),
            sliderInput("eval_sbp",
                        "Systolic blood pressure",
                        min = 0,
                        max = 400,
                        value = model_props$feat_props$median$eval_sbp),
            sliderInput("eval_pulse",
                        "Pulse rate",
                        min = 0,
                        max = 200,
                        value = model_props$feat_props$median$eval_pulse),
            sliderInput("eval_temp",
                        "Temperature",
                        min = 30.5,
                        max = 42.5,
                        value = model_props$feat_props$median$eval_temp),
            textInput("disp_created",
                      "Call time",
                      value = now())
            
        ),

        mainPanel(
            tabsetPanel(type = "tabs",
                        tabPanel("Prediction",
                            htmlOutput("ui")),
                        tabPanel("About",
                                 tagList(
                                     p(),
                                     "This app demonstrates the behaviour of a risk assessment instrument reflecting a
                                   patient's risk for deterioration at the time of initial evaluation on scene. The insrument 
                                     is based on methods described in our research article", 
                                     a("A validation of machine learning-based risk scores in the prehospital setting",
                                       href="https://doi.org/10.1371/journal.pone.0226518"),
                                       ". This user inferface contains no code to estimate risk scores, but rather performs API calls to", 
                                     a("openTriage",
                                       href="https://github.com/dnspangler/openTriage"),
                                     ", a back-end system for estimating risk scores for use in clinical decision support systems.", 
                                     "Please note that these scores have not been validated outside of Region Uppsala in Sweden, and 
                                     that this tool is provided for demonstation purposes only. If you use this on patients
                                     outside of this context, you could kill people.",
                                     p(),
                                     "A patient with median values for each predictor included in the models
                                   is described by default. Modify the model parameters in the sidebar and see how the risk assessment
                                   instrument reacts. If no choice is made for the multiple choice values, a missing/other value is assumed.
                                   Multiple choice options are sorted in order of descending average variable importance across all models.",
                                     p(),
                                     "The raw score is displayed for the patient at the top of the screen, and the relative position 
                                     of the score with respect to all scores in a test dataset is displayed. The Likelihoods of each component 
                                     outcome in the score and their percentile ranks are displayed beneath the graph. Finally, average SHAP values 
                                     for each variable across the component outcomed are displayed to explain how the model arrived at the final 
                                     score.",
                                     p(),
                                     "The API this front-end system employs mey be accessed via a POST request to the /predict/ endpoint of this server.
                                     The API expects a JSON file with a specific format. You can download a test a test payload based on the currently 
                                     selected predictors here:",
                                     p(),
                                     downloadButton("download",
                                                  "Download test data"),
                                 p(),
                                 fluidRow(style="text-align: center;padding:60px;",
                                          a(img(src="as.png", width = "200px"), 
                                            href="https://pubcare.uu.se/research/hsr/Ongoing+projects/Political%2C+administrative+and+medical+decision-making/emdai/"),
                                          p(),
                                          a(img(src="uu.png", width = "200px"), 
                                            href="http://ucpr.se/projects/emdai/"),
                                          p(),
                                          a(img(src="vinnova.png", width = "200px"), 
                                            href="https://www.vinnova.se/en/p/emdai-a-machine-learning-based-decision-support-tool-for-emergency-medical-dispatch/")
                                 ))))
        )
    )
)

server <- function(input, output) {
    
    get_payload <- function(input) {
        
       out = toJSON(list("gui" = list(
            "region"="Uppsala",
            "disp_created"=input$disp_created,
            "disp_age"=input$disp_age,
            "disp_gender"=input$disp_gender,
            "disp_cats"=paste(input$disp_cats,collapse="|"),
            "disp_prio"=as.numeric(input$disp_prio),
            "eval_breaths"= input$eval_breaths,
            "eval_spo2"= input$eval_spo2,
            "eval_sbp"= input$eval_sbp,
            "eval_pulse"=input$eval_pulse,
            "eval_avpu"=input$eval_avpu,
            "eval_temp"=input$eval_temp
        )),pretty = T)
    
        return(out)
    }
    
    output$download <- downloadHandler(
        
        filename = function() {
            paste('test', Sys.Date(), '.json', sep='')
        },
        
        content = function(con) {
            write(get_payload(input), con)
        }
    )
    
    output$ui <- renderUI({
        
        payload <- get_payload(input)
        
        r <- POST(paste0(server_url,"/predict/"), content_type_json(), body = payload)
        
        r_list <- content(r,"parsed")
        
        if(class(r_list) == "list"){
            
            HTML(as.character(r_list$gui$html))
            
        }else{
            
            HTML(as.character(r_list))
            
        }
    })
}

# Run the application 
shinyApp(ui = ui, server = server)
