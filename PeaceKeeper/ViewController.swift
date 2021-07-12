//
//  ViewController.swift
//  test
//
//  Created by JongGeun on 2021/06/09.
//

import UIKit
import WebKit
import CoreML
import Foundation

class ViewController: UIViewController,WKUIDelegate,WKNavigationDelegate, UIScrollViewDelegate{

    @IBOutlet var Exit: UIBarButtonItem!
    @IBOutlet var URL_Change: UIBarButtonItem!
    @IBOutlet var webView: WKWebView!
    var replaceText:String = "I Love You"
    let model = try? convert_model()
    let mainQueue = OperationQueue()
    var lastOffsetY :CGFloat = 0.0
    var innerWeb:String = ""
    var timer:Timer = Timer.init()
    
    override func loadView() {
        super.loadView()
        
        // navigationToolBar 설정
        self.navigationController?.isToolbarHidden = false
        self.navigationController?.hidesBarsWhenKeyboardAppears = true
        self.navigationController?.navigationBar.isTranslucent = true
        self.navigationController?.setStatusBar(backgroundColor: .systemBackground)
        
        // toolBar 설정
        let toolbarBack = UIBarButtonItem(title: "<", style: .plain, target: self, action: #selector(backButtonAction))
        let toolbarSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil)
        let toolbarForward = UIBarButtonItem(title: ">", style: .plain, target: self, action: #selector(forwardButtonAction))
        let toolbarReplaceTextChange = UIBarButtonItem(title: "Replace Text Change", style: .plain, target: self, action: #selector(replaceTextChange))
        self.setToolbarItems([toolbarBack, toolbarSpace, toolbarReplaceTextChange, toolbarSpace, toolbarForward], animated: true)
        
        // webView 설정
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.scrollView.delegate = self
        webView.translatesAutoresizingMaskIntoConstraints = true
        webView.allowsBackForwardNavigationGestures = true  //뒤로가기 제스쳐 허용
        webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = true //자바스크립트 활성화
        webView.configuration.allowsInlineMediaPlayback = true
        webView.configuration.allowsPictureInPictureMediaPlayback = true
        webView.configuration.allowsAirPlayForMediaPlayback = true
        
        // webView와 webView안에 script를 연동하기 위한 scriptHandler 설정
        let webConfiguration = WKWebViewConfiguration();
        let contentController = webView.configuration.userContentController
        contentController.add(self, name: "scriptHandler")
        webConfiguration.userContentController = contentController
        
        // IPhone 모델마다 statusBar 높이가 다른 모델이 있어 자동으로 맞추는 코드 삽입
        let rootViewFrame = UIApplication.shared.windows.first!.rootViewController
        let statusBerHeight = rootViewFrame!.view.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
        webView.frame = CGRect(x: 0, y: statusBerHeight, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - statusBerHeight)
        self.view.addSubview(webView)
    }
    
    func loadWebPage(_ url: String){
        let url = URL(string: url)
        let request = URLRequest(url: url!)
        webView.load(request)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        swipeRecognizer()
        webViewIntialPage()
        self.timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.crawlingWeb), userInfo: nil, repeats: true)
    }
    
    func webViewIntialPage() {
        do {
            let filePath = Bundle.main.path(forResource: "index", ofType: "html")
            let contents =  try String(contentsOfFile: filePath!, encoding: .utf8)
            let baseUrl = URL(fileURLWithPath: filePath!)
            webView.loadHTMLString(contents as String, baseURL: baseUrl)
        } catch {
            self.errorMessage(error: "File HTML error")
        }
    }
    
    // scroll시 navigation & tool bar 숨김
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // scroll up
        if lastOffsetY >= webView.scrollView.contentOffset.y || webView.scrollView.contentOffset.y <= 0{
            if self.navigationController!.isNavigationBarHidden {
                self.navigationController!.setNavigationBarHidden(false, animated: true)
            }
            if self.navigationController!.isToolbarHidden {
                self.navigationController?.setToolbarHidden(false, animated: true)
            }
            if lastOffsetY <= 0 {
                lastOffsetY = 0.0
            } else {
                lastOffsetY = webView.scrollView.contentOffset.y
            }
        }
        // scroll down
        else {
            if !self.navigationController!.isNavigationBarHidden {
                self.navigationController!.setNavigationBarHidden(true, animated: true)
            }
            if !self.navigationController!.isToolbarHidden {
                self.navigationController?.setToolbarHidden(true, animated: true)
            }
            lastOffsetY = webView.scrollView.contentOffset.y
        }
    }
    
    // navigationTopBar 설정
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent != nil && self.navigationItem.titleView == nil {
            initNavigationItemTitleView()
        }
    }

    private func initNavigationItemTitleView() {
        let titleView = UILabel()
        titleView.text = "PeaceKeeper"
        titleView.font = UIFont(name: "HelveticaNeue-Medium", size: 17)
        let width = titleView.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)).width
        titleView.frame = CGRect(origin:CGPoint.zero, size:CGSize(width: width, height: 500))
        self.navigationItem.titleView = titleView

        let recognizer = UITapGestureRecognizer(target: self, action: #selector(self.titleWasTapped))
        titleView.isUserInteractionEnabled = true
        titleView.addGestureRecognizer(recognizer)
    }

    @objc private func titleWasTapped() {
        if !self.navigationController!.isNavigationBarHidden {
            self.navigationController!.setNavigationBarHidden(true, animated: true)
        }
        if !self.navigationController!.isToolbarHidden {
            self.navigationController?.setToolbarHidden(true, animated: true)
        }
    }
    
    @objc func crawlingWeb() {
        webView.evaluateJavaScript( "document.body.innerText;") { (result, error) in
            if error == nil {
                // result -> String 으로 변환
                let innerText: String = (result as? String)!
                
                if innerText != self.innerWeb {
                    // innerText -> Array<String>으로 변환
                    let text: Array<String> = innerText.components(separatedBy: "\n")
                    // Set을 이용하여 배열의 중복 제거
                    let removedDuplicate: Set = Set(text)
                    var arr = Array(removedDuplicate)
                    // 빈 배열 제거
                    arr.removeAll(where: { $0.isEmpty })
                    
                    // 정규식을 통해 이모티콘 제거
                    for i in 0 ..< arr.count {
                        if !arr[i].getArrayAfterRegex(regex: "^[0-9a-zA-Zㄱ-ㅎㅏ-ㅣ가-힣+=-?!,.#$%@;&*\\[\\]₩~'\" ]$").isEmpty {
                            let replace = arr[i].getArrayAfterRegex(regex: "^[0-9a-zA-Zㄱ-ㅎㅏ-ㅣ가-힣+=-?!,.#$%&*\\[\\]₩~'\" ]$")
                            for j in 0 ..< replace.count {
                                arr[i] = arr[i].replacingOccurrences(of: replace[j], with: "")
                            }
                        }
                    }
                    
                    // 백그라운드 큐잉 처리
                    self.mainQueue.addOperation {
                        self.classify(text: arr)
                    }
                    
                    self.innerWeb = innerText
                }
            }
        }
    }
    
    // 모달창 닫힐때 앱 종료현상 방지.
    override func didReceiveMemoryWarning() { super.didReceiveMemoryWarning() }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // toolBar에 앞으로 가기 버튼과 뒤로가기 버튼은 실행 가능할때만 Enable하게 설정.
        if webView.canGoBack {
            toolbarItems![0].isEnabled = true
        } else {
            toolbarItems![0].isEnabled = false
        }
        
        if webView.canGoForward {
            toolbarItems![4].isEnabled = true
        } else {
            toolbarItems![4].isEnabled = false
        }
        
        crawlingWeb()
    }
    
    //alert 처리
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void){
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "확인", style: .default, handler: { (action) in completionHandler() }))
        self.present(alertController, animated: true, completion: nil) }

    //confirm 처리
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "취소", style: .default, handler: { (action) in completionHandler(false) }))
        alertController.addAction(UIAlertAction(title: "확인", style: .default, handler: { (action) in completionHandler(true) }))
        self.present(alertController, animated: true, completion: nil) }
    
    // href="_blank" 처리
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
        return nil }
    
    // 잘못된 URL을 입력했을때
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let alert = UIAlertController(title: "URL Change", message: "URL을 잘못 입력하셨습니다. 다시 확인해주세요.", preferredStyle: .alert)
        let ok = UIAlertAction(title: "확인", style: .default, handler: nil)
        alert.addAction(ok)
        self.present(alert, animated: true)
    }
    
    // 스와이프 초기 설정
    func swipeRecognizer() {
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(self.respondToSwipeGesture(_:)))
        swipeRight.direction = UISwipeGestureRecognizer.Direction.right
        self.view.addGestureRecognizer(swipeRight)
        
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(self.respondToSwipeGesture(_:)))
        swipeLeft.direction = UISwipeGestureRecognizer.Direction.left
        self.view.addGestureRecognizer(swipeLeft)
    }
    
    // 제스처 함수
    @objc func respondToSwipeGesture(_ gesture: UIGestureRecognizer){
        if let swipeGesture = gesture as? UISwipeGestureRecognizer {
            switch swipeGesture.direction{
            case UISwipeGestureRecognizer.Direction.right:
                if webView.canGoBack {
                    webView.goBack()
                }
                self.dismiss(animated: true, completion: nil)
            case UISwipeGestureRecognizer.Direction.left:
                if webView.canGoForward {
                    webView.goForward()
                }
                self.dismiss(animated: true, completion: nil)
            default: break
            }
        }
    }
    
    // 리스트 팝업 처리
    func showAlert(style: UIAlertController.Style) {
        var nowURL:String = webView.url!.relativeString
        if nowURL.range(of: "/PeaceKeeper.app/index.html", options: .backwards) != nil {
            nowURL = "앱 초기화면"
        }
        let alert = UIAlertController(title: "URL Change", message: "변경하실 URL을 선택하세요\n현재 URL : " + nowURL, preferredStyle: .actionSheet)
        let youtube = UIAlertAction(title: "Youtube", style: .default) { (action) in
            self.loadWebPage("https://www.youtube.com/")
        }
        let naver = UIAlertAction(title: "Naver", style: .default) { (action) in
            self.loadWebPage("https://www.naver.com/")
        }
        let daum = UIAlertAction(title: "Daum", style: .default) { (action) in
            self.loadWebPage("https://www.daum.net/")
        }
        let afreeca = UIAlertAction(title: "앱 초기화면", style: .default) { (action) in
            self.webViewIntialPage()
        }
        let custom = UIAlertAction(title: "직접 입력", style: .default, handler: customURLAlert(_:))
        let cancel = UIAlertAction(title: "취소", style: .cancel, handler: nil)
        
        alert.addAction(youtube)
        alert.addAction(naver)
        alert.addAction(daum)
        alert.addAction(afreeca)
        alert.addAction(custom)
        alert.addAction(cancel)
        
        self.addActionSheetForiPad(actionSheet: alert)
        self.present(alert, animated: true, completion: nil)
    }
    
    // 직접 URL을 입력하는 기능
    @objc func customURLAlert(_ sender: Any){
        let alert = UIAlertController(title: "URL Change", message: "바꾸실 URL을 입력해주세요", preferredStyle: .alert)
        
        let cancel = UIAlertAction(title: "취소", style: .cancel, handler: nil)
        let ok = UIAlertAction(title: "확인", style: .default){ (action) in
            var url = (alert.textFields?[0].text)!
            let flagHttp = url.hasPrefix("http://")
            let flagHttps = url.hasPrefix("https://")
            if !flagHttp && !flagHttps {
                url = "http://" + url
            }
            self.loadWebPage(url)
        }
        
        alert.addTextField { UITextField in
            UITextField.placeholder = "www.naver.com"
        }
        alert.addAction(cancel)
        alert.addAction(ok)
        
        self.present(alert, animated: true)
    }
    
    // Exit 처리
    func exitAction() {
        let alert = UIAlertController(title: "Exit", message: "종료하시겠습니까?", preferredStyle: UIAlertController.Style.alert)
        let okAction = UIAlertAction(title: "OK", style: .default) {(action) in
            self.mainQueue.cancelAllOperations()
            UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
            exit(0)
        }
        let cancel = UIAlertAction(title: "cancel", style: .destructive, handler : nil)

        alert.addAction(cancel)
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }
    
    // Error 메시지 알림
    func errorMessage(error: String) {
        let alert = UIAlertController(title: "Error", message: error, preferredStyle: UIAlertController.Style.alert)
        let okAction = UIAlertAction(title: "OK", style: .default) {(action) in
            UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
        }
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func URL_Change(_ sender: Any) {
        showAlert(style: .actionSheet)
    }
    
    @IBAction func Exit(_ sender: Any) {
        self.exitAction()
    }
    
    @objc func backButtonAction() {
        if webView.canGoBack {
            webView.goBack()
        }
    }
    
    @objc func forwardButtonAction() {
        if webView.canGoForward {
            webView.goForward()
        }
    }
    
    @objc func replaceTextChange() {
        let alert = UIAlertController(title: "Replace Text Change", message: "바뀌어질 텍스트를 입력해주세요", preferredStyle: .alert)
        
        let cancel = UIAlertAction(title: "취소", style: .cancel, handler: nil)
        let ok = UIAlertAction(title: "확인", style: .default){ (action) in
            let text = (alert.textFields?[0].text)!
            self.replaceText = text
        }
        
        alert.addTextField { UITextField in
            UITextField.placeholder = self.replaceText
        }
        alert.addAction(cancel)
        alert.addAction(ok)
        
        self.present(alert, animated: true)
    }
    
    @objc func classify(text: Array<String>) {
        let option = MLPredictionOptions()
        option.usesCPUOnly = true
        
        // 전체 문자열을 " "을 기준으로 나누어 2차원배열 생성.
        var wordArrays : [[String]] = []
        for index in text {
            wordArrays.append(index.split(separator: " ").map(String.init))
        }
        
        // 나눈 2차원배열을 토큰화하여 Float 형태로 저장.
        var list : [[NSNumber]] = []
        for index in wordArrays {
            list.append(tokenizer(words: index, length: wordArrays.count))
        }
        
        for index in stride(from: 0, to: list.count, by: 1) {
            // 만약 wordArrays[index].count가 0 일 경우 embadding_input으로 들어가는 행렬이 0x1이기 때문에 model_input을 할 수 없어 continue 처리.
            if wordArrays[index].count == 0 {
                continue
            }
            let input_data = try? MLMultiArray(shape:[NSNumber(integerLiteral: wordArrays[index].count), 1], dataType:.double)
            for (index2,item) in list[index].enumerated() {
                input_data![index2] = item
            }
            
            let input = convert_modelInput(embedding_input: input_data!)
            let prediction = try? model?.prediction(input: input, options: option)
            
            // 만약 빈문자만 있거나 prediction할 수 없는 특수 데이터가 있으면 prediction값을 nil로 내뱉기 때문에 이또한 continue 처리.
            if prediction == nil {
                continue
            }
            
            var sum_bad = 0.0
            for index2 in stride(from: 0, to: prediction!.Identity.count, by: 1) {
                if index2 % 2 == 0 {
                    sum_bad += Double(truncating: prediction!.Identity[index2])
                }
            }
            let avg_bad = sum_bad / Double(prediction!.Identity.count / 2)
            
            // 해당 문자열이 cussList에 포함될 경우(일치와 같음) 무조건 치환시킴
            if cussList.contains(text[index]) {
                DispatchQueue.main.async {
                    self.webViewReplaceText(word: text[index])
                }
            } else {
                // 아니면 prediction 한 값의 기준치를 기준으로 분류
                if avg_bad <= 0.5 {
                    // 정규식으로 필터링을 할때 아예 빈 배열로 될 수도 있기 때문에 한번더 체크
                    if !text[index].isEmpty {
                        // print("positive : ", avg_bad, text[index])
                    }
                } else {
                    if !text[index].isEmpty {
                        // print("negative : ", avg_bad, text[index])
                        DispatchQueue.main.async {
                            self.webViewReplaceText(word: text[index])
                        }
                    }
                }
            }
        }
    }
    
    @objc func tokenizer(words: [String], length: Int) -> [NSNumber] {
        var tokens : [NSNumber] = []
        for (index, word) in words.enumerated() {
            if cussList.contains(word) {
                tokens.insert(NSNumber(value: 5.0), at: index)
            } else {
                tokens.insert(NSNumber(value: 0.0), at: index)
            }
        }
        return tokens
    }
    
    @objc func webViewReplaceText(word: String) {
        // "(쌍따옴표) 를 꼭 치환해주어야 javascript 실행 시 이스케이프가 되지 않는다
        let text = word.replacingOccurrences(of: "\"", with: "\\\"")
        webView.evaluateJavaScript( "new function(){"                                                   +
                                    "var chooseText = function(parent) {"                               +
                                    "   if(parent.childElementCount == 0) {"                            +
                                    "       if(parent.textContent.indexOf(\"" + text + "\") >= 0){"     +
                                    "           parent.textContent = \"" + self.replaceText + "\";"     +
                                    "       }"                                                          +
                                    "   } else {"                                                       +
                                    "       for(var i=0; i<parent.childElementCount; i++) {"            +
                                    "           chooseText(parent.children[i]);"                        +
                                    "       }"                                                          +
                                    "   }"                                                              +
                                    "};"                                                                +
                                    "var Inner = document.querySelectorAll('div');"                     +
                                    "for(var i=0; i<Inner.length;i++) {"                                +
                                    "   chooseText(Inner[i]);"                                          +
                                    "} return true };") { (result, error) in
            if error != nil {
                self.errorMessage(error: error.debugDescription)
                print(error.debugDescription)
            }
        }
    }
}

extension ViewController : WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "scriptHandler" {
            loadWebPage(message.body as! String)
        }
    }
}

extension String{
    func getArrayAfterRegex(regex: String) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: self,
                                        range: NSRange(self.startIndex..., in: self))
            return results.map {
                String(self[Range($0.range, in: self)!])
            }
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return []
        }
    }
}

extension UINavigationController {
    func setStatusBar(backgroundColor: UIColor) {
        let statusBarFrame: CGRect
        if #available(iOS 13.0, *) {
            statusBarFrame = view.window?.windowScene?.statusBarManager?.statusBarFrame ?? CGRect.zero
        } else {
            statusBarFrame = UIApplication.shared.statusBarFrame
        }
        let statusBarView = UIView(frame: statusBarFrame)
        statusBarView.backgroundColor = backgroundColor
        statusBarView.exerciseAmbiguityInLayout()
        view.addSubview(statusBarView)
    }
}

extension UIViewController {
  public func addActionSheetForiPad(actionSheet: UIAlertController) {
    if let popoverPresentationController = actionSheet.popoverPresentationController {
      popoverPresentationController.sourceView = self.view
      popoverPresentationController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
      popoverPresentationController.permittedArrowDirections = []
    }
  }
}
