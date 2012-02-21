var MindWave = (function () {
    return {
        isPresent: function() {
            return Math.random() > 0.5;
        },
        getThinkingLevel: function() {
            return Math.floor(Math.random()*101);
        },
        getRelaxationLevel: function() {
            return Math.floor(Math.random()*101);
        }
    };
}());

##register is_present : -> bool
##args()
{
    return MindWave.isPresent();
}

##register get_thinking_level : -> int
##args()
{
    return MindWave.getThinkingLevel();
}

##register get_relaxation_level : -> int
##args()
{
    return MindWave.getRelaxationLevel();
}
