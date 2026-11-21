var figureDayDiff = (currentTime,passedTime)=>{
	let dateDiff = currentTime - passedTime;//时间差的毫秒数
	let dayDiff = Math.floor(dateDiff / (24 * 3600 * 1000));//计算出相差天数
	return dayDiff;
}


var ebbinghausLevelFilter = (vocabularyList)=>{
	
	let filterList=[];
	let currentTime = new Date().getTime();
	for (let key in vocabularyList) {
		let level = vocabularyList[key].level;
		
		if(figureDayDiff(currentTime,vocabularyList[key].reviewTime)<1) {
			continue;
		}
		
		switch (level){
			case 0:
				if(figureDayDiff(currentTime,vocabularyList[key].reviewTime)>=1){
					filterList.push(vocabularyList[key]);
				}
				break;
			case 1:
				if(figureDayDiff(currentTime,vocabularyList[key].reviewTime)>=1){
					filterList.push(vocabularyList[key]);
				}
				break;
			case 2:
				if(figureDayDiff(currentTime,vocabularyList[key].reviewTime)>=2){
					filterList.push(vocabularyList[key]);
				}
				break;
			case 3:
				if(figureDayDiff(currentTime,vocabularyList[key].reviewTime)>=4){
					filterList.push(vocabularyList[key]);
				}
				break;	
			case 4:
				if(figureDayDiff(currentTime,vocabularyList[key].reviewTime)>=7){
					filterList.push(vocabularyList[key]);
				}
				break;	
			case 5:
				if(figureDayDiff(currentTime,vocabularyList[key].reviewTime)>=15){
					filterList.push(vocabularyList[key]);
				}
				break;
			case 6:
				if(figureDayDiff(currentTime,vocabularyList[key].reviewTime)>=30){
					filterList.push(vocabularyList[key]);
				}
				break;
			case 7:
				if(figureDayDiff(currentTime,vocabularyList[key].reviewTime)>=45){
					filterList.push(vocabularyList[key]);
				}
				break;
			case 8:
				if(figureDayDiff(currentTime,vocabularyList[key].reviewTime)>=60){
					filterList.push(vocabularyList[key]);
				}
				break;
			case 9:
				if(figureDayDiff(currentTime,vocabularyList[key].reviewTime)>=90){
					filterList.push(vocabularyList[key]);
				}
				break;
			case 10:
				if(figureDayDiff(currentTime,vocabularyList[key].reviewTime)>=135){
					filterList.push(vocabularyList[key]);
				}
				break;
			case 11:
				if(figureDayDiff(currentTime,vocabularyList[key].reviewTime)>=180){
					filterList.push(vocabularyList[key]);
				}
				break;	
			case 12:
				if(figureDayDiff(currentTime,vocabularyList[key].reviewTime)>=210){
					filterList.push(vocabularyList[key]);
				}
				break;
			case 13:
				if(figureDayDiff(currentTime,vocabularyList[key].reviewTime)>=270){
					filterList.push(vocabularyList[key]);
				}
				break;
			case 14:
				if(figureDayDiff(currentTime,vocabularyList[key].reviewTime)>=300){
					filterList.push(vocabularyList[key]);
				}
				break;
			case 15:
				if(figureDayDiff(currentTime,vocabularyList[key].reviewTime)>=365){
					filterList.push(vocabularyList[key]);
				}
				break;
			case 16:
				if(figureDayDiff(currentTime,vocabularyList[key].reviewTime)>=545){
					filterList.push(vocabularyList[key]);
				}
				break;
			case 17:
				if(figureDayDiff(currentTime,vocabularyList[key].reviewTime)>=730){
					filterList.push(vocabularyList[key]);
				}
				break;
			case 18:
				if(figureDayDiff(currentTime,vocabularyList[key].reviewTime)>=1095){
					filterList.push(vocabularyList[key]);
				}
				break;
			case 19:
				if(figureDayDiff(currentTime,vocabularyList[key].reviewTime)>=1460){
					filterList.push(vocabularyList[key]);
				}
				break;	
			default:
				break;
		}
	}
	return filterList;
}

module.exports = ebbinghausLevelFilter;